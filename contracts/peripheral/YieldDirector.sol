// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.10;

import {IERC20} from "../interfaces/IERC20.sol";
import {IsNORO} from "../interfaces/IsNORO.sol";
import {IStaking} from "../interfaces/IStaking.sol";
import {IYieldDirector} from "../interfaces/IYieldDirector.sol";
import {SafeERC20} from "../libraries/SafeERC20.sol";
import {YieldSplitter} from "../types/YieldSplitter.sol";

/**
    @title  YieldDirector (codename Tyche) 
    @notice This contract allows donors to deposit their gNORO and donate their rebases
            to any address. Donors will be able to withdraw the sNORO equivalent of their principal
            gNORO at any time. Donation recipients can also redeem accrued rebases at any time.
    @dev    Any functions dealing with initial deposits will take an address (because no ID has been
            assigned). After a user has deposited, all functions dealing with deposits (like
            withdraw or redeem functions) will take the ID of the deposit. All functions that return
            aggregated data grouped by user will take an address (iterates across all relevant IDs).
 */
contract YieldDirector is IYieldDirector, YieldSplitter {
    using SafeERC20 for IERC20;

    error YieldDirector_InvalidAddress();
    error YieldDirector_InvalidDeposit();
    error YieldDirector_InvalidUpdate();
    error YieldDirector_InvalidWithdrawal();
    error YieldDirector_NotYourYield();
    error YieldDirector_NoDeposits();
    error YieldDirector_WithdrawalsDisabled();
    error YieldDirector_RedeemsDisabled();

    address public immutable sNORO;
    address public immutable gNORO;
    IStaking public immutable staking;

    mapping(address => uint256[]) public recipientIds; // address -> array of deposit id's donating yield to the user
    mapping(uint256 => address) public recipientLookup; // depositId -> recipient

    bool public depositDisabled;
    bool public withdrawDisabled;
    bool public redeemDisabled;

    event Deposited(address indexed donor_, address indexed recipient_, uint256 amount_);
    event Withdrawn(address indexed donor_, address indexed recipient_, uint256 amount_);
    event AllWithdrawn(address indexed donor_, uint256 indexed amount_);
    event Donated(address indexed donor_, address indexed recipient_, uint256 amount_);
    event Redeemed(address indexed recipient_, uint256 amount_);
    event EmergencyShutdown(bool active_);

    constructor(
        address sNoro_,
        address gNoro_,
        address staking_,
        address authority_
    ) YieldSplitter(sNoro_, authority_) {
        if (sNoro_ == address(0) || gNoro_ == address(0) || staking_ == address(0) || authority_ == address(0))
            revert YieldDirector_InvalidAddress();

        sNORO = sNoro_;
        gNORO = gNoro_;
        staking = IStaking(staking_);

        IERC20(sNORO).safeApprove(address(staking), type(uint256).max);
    }

    /************************
     * Modifiers
     ************************/
    function isInvalidDeposit(uint256 amount_, address recipient_) internal view returns (bool) {
        return depositDisabled || amount_ == 0 || recipient_ == address(0);
    }

    function isInvalidUpdate(uint256 depositId_, uint256 amount_) internal view returns (bool) {
        return depositDisabled || amount_ == 0 || depositInfo[depositId_].depositor == address(0);
    }

    function isInvalidWithdrawal(uint256 amount_) internal view returns (bool) {
        return withdrawDisabled || amount_ == 0;
    }

    /************************
     * Donor Functions
     ************************/

    /**
        @notice Deposit gNORO, records sender address and assign rebases to recipient
        @param amount_ Amount of gNORO debt issued from donor to recipient
        @param recipient_ Address to direct staking yield and vault shares to
    */
    function deposit(uint256 amount_, address recipient_) external override returns (uint256 depositId) {
        depositId = _createDeposit(amount_, recipient_);

        IERC20(gNORO).safeTransferFrom(msg.sender, address(this), amount_);
    }

    /**
        @notice Deposit sNORO, wrap to gNORO, and records sender address and assign rebases to recipeint
        @param amount_ Amount of sNORO debt issued from donor to recipient
        @param recipient_ Address to direct staking yield and vault shares to
    */
    function depositSnoro(uint256 amount_, address recipient_) external override returns (uint256 depositId) {
        uint256 gnoroAmount = _toAgnostic(amount_);
        depositId = _createDeposit(gnoroAmount, recipient_);

        IERC20(sNORO).safeTransferFrom(msg.sender, address(this), amount_);
        staking.wrap(address(this), amount_);
    }

    /**
        @notice Deposit additional gNORO, and update deposit record
        @param depositId_ Deposit ID to direct additional gNORO to
        @param amount_ Amount of new gNORO debt issued from donor to recipient
    */
    function addToDeposit(uint256 depositId_, uint256 amount_) external override {
        _increaseDeposit(depositId_, amount_);

        IERC20(gNORO).safeTransferFrom(msg.sender, address(this), amount_);
    }

    /**
        @notice Deposit additional sNORO, wrap to gNORO, and update deposit record
        @param depositId_ Deposit ID to direct additional gNORO to
        @param amount_ Amount of new sNORO debt issued from donor to recipient
    */
    function addToSnoroDeposit(uint256 depositId_, uint256 amount_) external override {
        uint256 gnoroAmount = _toAgnostic(amount_);
        _increaseDeposit(depositId_, gnoroAmount);

        IERC20(sNORO).safeTransferFrom(msg.sender, address(this), amount_);
        staking.wrap(address(this), amount_);
    }

    /**
        @notice Withdraw donor's gNORO from vault
        @param depositId_ Deposit ID to remove gNORO deposit from
        @param amount_ Amount of gNORO deposit to remove and return to donor
    */
    function withdrawPrincipal(uint256 depositId_, uint256 amount_) external override {
        uint256 amountWithdrawn = _withdraw(depositId_, amount_);

        IERC20(gNORO).safeTransfer(msg.sender, amountWithdrawn);
    }

    /**
        @notice Withdraw donor's gNORO from vault, and return it as sNORO
        @param depositId_ Deposit ID to remove gNORO debt from
        @param amount_ Amount of gNORO debt to remove and return to donor as sNORO
    */
    function withdrawPrincipalAsSnoro(uint256 depositId_, uint256 amount_) external override {
        uint256 amountWithdrawn = _withdraw(depositId_, amount_);

        staking.unwrap(msg.sender, amountWithdrawn);
    }

    /**
        @notice Withdraw all gNORO from all donor positions
    */
    function withdrawAll() external override {
        if (withdrawDisabled) revert YieldDirector_WithdrawalsDisabled();

        uint256[] memory depositIds = depositorIds[msg.sender];

        uint256 depositsLength = depositIds.length;
        if (depositsLength == 0) revert YieldDirector_NoDeposits();

        uint256 principalTotal = 0;

        for (uint256 index = 0; index < depositsLength; ++index) {
            DepositInfo storage currDeposit = depositInfo[depositIds[index]];

            principalTotal += currDeposit.principalAmount;

            _withdrawAllPrincipal(depositIds[index], msg.sender);
        }

        uint256 agnosticAmount = _toAgnostic(principalTotal);

        emit AllWithdrawn(msg.sender, agnosticAmount);

        IERC20(gNORO).safeTransfer(msg.sender, agnosticAmount);
    }

    /************************
     * View Functions
     ************************/

    /**
        @notice Get deposited gNORO amounts for specific recipient (updated to current index
                based on sNORO equivalent amount deposit)
        @param donor_ Address of user donating yield
        @param recipient_ Address of user receiving donated yield
    */
    function depositsTo(address donor_, address recipient_) external view override returns (uint256) {
        uint256[] memory depositIds = depositorIds[donor_];

        uint256 totalPrincipalDeposits;
        for (uint256 index = 0; index < depositIds.length; ++index) {
            uint256 id = depositIds[index];

            if (recipientLookup[id] == recipient_) {
                totalPrincipalDeposits += depositInfo[id].principalAmount;
            }
        }

        return _toAgnostic(totalPrincipalDeposits);
    }

    /**
        @notice Return total amount of donor's gNORO deposited (updated to current index based
                on sNORO equivalent amount deposited)
        @param donor_ Address of user donating yield
    */
    function totalDeposits(address donor_) external view override returns (uint256) {
        uint256[] memory depositIds = depositorIds[donor_];
        uint256 principalTotal = 0;

        for (uint256 index = 0; index < depositIds.length; ++index) {
            principalTotal += depositInfo[depositIds[index]].principalAmount;
        }

        return _toAgnostic(principalTotal);
    }

    /**
        @notice Return arrays of donor's recipients and deposit amounts (gNORO value based on
                sNORO equivalent deposit), matched by index
        @param donor_ Address of user donating yield
    */
    function getAllDeposits(address donor_) external view override returns (address[] memory, uint256[] memory) {
        uint256[] memory depositIds = depositorIds[donor_];

        uint256 len = depositIds.length == 0 ? 1 : depositIds.length;

        address[] memory addresses = new address[](len);
        uint256[] memory agnosticDeposits = new uint256[](len);

        if (depositIds.length == 0) {
            addresses[0] = address(0);
            agnosticDeposits[0] = 0;
        } else {
            for (uint256 index = 0; index < len; ++index) {
                addresses[index] = recipientLookup[depositIds[index]];
                agnosticDeposits[index] = _toAgnostic(depositInfo[depositIds[index]].principalAmount);
            }
        }

        return (addresses, agnosticDeposits);
    }

    /**
        @notice Return total amount of gNORO donated to recipient since last full redemption
        @param donor_ Address of user donating yield
        @param recipient_ Address of user recieiving donated yield
    */
    function donatedTo(address donor_, address recipient_) external view override returns (uint256) {
        uint256[] memory depositIds = depositorIds[donor_];

        uint256 totalRedeemable;
        for (uint256 index = 0; index < depositIds.length; ++index) {
            if (recipientLookup[depositIds[index]] == recipient_) {
                totalRedeemable += redeemableBalance(depositIds[index]);
            }
        }

        return totalRedeemable;
    }

    /**
        @notice Return total amount of gNORO donated from donor since last full redemption
        @param donor_ Address of user donating yield
    */
    function totalDonated(address donor_) external view override returns (uint256) {
        uint256[] memory depositIds = depositorIds[donor_];

        uint256 principalTotal = 0;
        uint256 agnosticTotal = 0;

        for (uint256 index = 0; index < depositIds.length; ++index) {
            DepositInfo storage currDeposit = depositInfo[depositIds[index]];

            principalTotal += currDeposit.principalAmount;
            agnosticTotal += currDeposit.agnosticAmount;
        }

        return _getOutstandingYield(principalTotal, agnosticTotal);
    }

    /************************
     * Recipient Functions
     ************************/

    /**
        @notice Get redeemable gNORO balance of a specific deposit
        @param depositId_ Deposit ID for this donation
    */
    function redeemableBalance(uint256 depositId_) public view override returns (uint256) {
        DepositInfo storage currDeposit = depositInfo[depositId_];

        return _getOutstandingYield(currDeposit.principalAmount, currDeposit.agnosticAmount);
    }

    /**
        @notice Get redeemable gNORO balance of a recipient address
        @param recipient_ Address of user receiving donated yield
     */
    function totalRedeemableBalance(address recipient_) external view override returns (uint256) {
        uint256[] memory receiptIds = recipientIds[recipient_];

        uint256 agnosticRedeemable = 0;

        for (uint256 index = 0; index < receiptIds.length; ++index) {
            agnosticRedeemable += redeemableBalance(receiptIds[index]);
        }

        return agnosticRedeemable;
    }

    /**
        @notice Getter function for a recipient's list of IDs. This is needed for the frontend
                as public state variables that map to arrays only return one element at a time
                rather than the full array
    */
    function getRecipientIds(address recipient_) external view override returns (uint256[] memory) {
        return recipientIds[recipient_];
    }

    /**
        @notice Redeem recipient's donated amount of sNORO at current index from one donor as gNORO
        @param depositId_ Deposit ID for this donation
    */
    function redeemYield(uint256 depositId_) external override {
        uint256 amountRedeemed = _redeem(depositId_, msg.sender);

        IERC20(gNORO).safeTransfer(msg.sender, amountRedeemed);
    }

    /**
        @notice Redeem recipient's donated amount of sNORO at current index
        @param depositId_ Deposit id for this donation
    */
    function redeemYieldAsSnoro(uint256 depositId_) external override {
        uint256 amountRedeemed = _redeem(depositId_, msg.sender);

        staking.unwrap(msg.sender, amountRedeemed);
    }

    /**
        @notice Redeem recipient's full donated amount of sNORO at current index as gNORO
    */
    function redeemAllYield() external override {
        uint256 amountRedeemed = _redeemAll(msg.sender);

        IERC20(gNORO).safeTransfer(msg.sender, amountRedeemed);
    }

    /**
        @notice Redeem recipient's full donated amount of sNORO at current index as gNORO
    */
    function redeemAllYieldAsSnoro() external override {
        uint256 amountRedeemed = _redeemAll(msg.sender);

        staking.unwrap(msg.sender, amountRedeemed);
    }

    /**
        @notice Redeems yield from a deposit and sends it to the recipient
        @param id_ Id of the deposit.
    */
    function redeemYieldOnBehalfOf(uint256 id_) external override returns (uint256 amount_) {
        if (!hasPermissionToRedeem[msg.sender]) revert YieldDirector_NotYourYield();

        address recipient = recipientLookup[id_];

        amount_ = _redeem(id_, recipient);

        IERC20(gNORO).safeTransfer(recipient, amount_);
    }

    /**
        @notice Redeems all yield tied to a recipient and sends it to the recipient
        @param recipient_ recipient address.
    */
    function redeemAllYieldOnBehalfOf(address recipient_) external override returns (uint256 amount_) {
        if (!hasPermissionToRedeem[msg.sender]) revert YieldDirector_NotYourYield();

        amount_ = _redeemAll(recipient_);

        IERC20(gNORO).safeTransfer(recipient_, amount_);
    }

    /************************
     * Internal Functions
     ************************/

    /**
        @notice Creates a new deposit directing the yield from the deposited gNORO amount
                to the prescribed recipient
        @param amount_ Quantity of gNORO deposited redirecting yield to the recipient
        @param recipient_ The address of the user who will be entitled to claim the donated yield
    */
    function _createDeposit(uint256 amount_, address recipient_) internal returns (uint256 depositId) {
        if (isInvalidDeposit(amount_, recipient_)) revert YieldDirector_InvalidDeposit();

        depositId = _deposit(msg.sender, amount_);
        recipientIds[recipient_].push(depositId);
        recipientLookup[depositId] = recipient_;

        emit Deposited(msg.sender, recipient_, amount_);
    }

    /**
        @notice Increases the amount of gNORO directing yield to a recipient
        @param depositId_ The global ID number of the deposit to add the additional deposit to
        @param amount_ Quantity of new gNORO deposited redirecting yield to the current deposit's recipient
    */
    function _increaseDeposit(uint256 depositId_, uint256 amount_) internal {
        if (isInvalidUpdate(depositId_, amount_)) revert YieldDirector_InvalidUpdate();

        _addToDeposit(depositId_, amount_, msg.sender);

        emit Deposited(msg.sender, recipientLookup[depositId_], amount_);
    }

    /**
        @notice Withdraw gNORO deposit from vault
        @param depositId_ Deposit ID to remove gNORO deposit from
        @param amount_ Amount of gNORO deposit to remove and return to donor 
    */
    function _withdraw(uint256 depositId_, uint256 amount_) internal returns (uint256 amountWithdrawn) {
        if (isInvalidWithdrawal(amount_)) revert YieldDirector_InvalidWithdrawal();

        if (amount_ < _toAgnostic(depositInfo[depositId_].principalAmount)) {
            _withdrawPrincipal(depositId_, amount_, msg.sender);
            amountWithdrawn = amount_;
        } else {
            amountWithdrawn = _withdrawAllPrincipal(depositId_, msg.sender);
        }

        emit Withdrawn(msg.sender, recipientLookup[depositId_], amountWithdrawn);
    }

    /**
        @notice Redeem available gNORO yield from a specific deposit
        @param depositId_ Deposit ID to withdraw gNORO yield from
        @param recipient_ address of recipient
    */
    function _redeem(uint256 depositId_, address recipient_) internal returns (uint256 amountRedeemed) {
        if (redeemDisabled) revert YieldDirector_RedeemsDisabled();
        if (recipientLookup[depositId_] != recipient_) revert YieldDirector_NotYourYield();

        amountRedeemed = _redeemYield(depositId_);

        if (depositInfo[depositId_].principalAmount == 0) {
            _closeDeposit(depositId_, depositInfo[depositId_].depositor);

            uint256[] storage receiptIds = recipientIds[recipient_];
            uint256 idsLength = receiptIds.length;

            for (uint256 i = 0; i < idsLength; ++i) {
                if (receiptIds[i] == depositId_) {
                    // Remove id from recipient's ids array
                    receiptIds[i] = receiptIds[idsLength - 1]; // Delete integer from array by swapping with last element and calling pop()
                    receiptIds.pop();
                    break;
                }
            }

            delete recipientLookup[depositId_];
        }

        emit Redeemed(recipient_, amountRedeemed);
        emit Donated(depositInfo[depositId_].depositor, recipient_, amountRedeemed);
    }

    /**
        @notice Redeem all available gNORO yield from the vault
        @param recipient_ address of recipient
    */
    function _redeemAll(address recipient_) internal returns (uint256 amountRedeemed) {
        if (redeemDisabled) revert YieldDirector_RedeemsDisabled();

        uint256[] storage receiptIds = recipientIds[recipient_];

        // We iterate through the array back to front so that we can delete
        // elements from the array without changing the locations of any
        // entries that have not been checked yet
        for (uint256 index = receiptIds.length; index > 0; index--) {
            uint256 currIndex = index - 1;

            address currDepositor = depositInfo[receiptIds[currIndex]].depositor;
            uint256 currRedemption = _redeemYield(receiptIds[currIndex]);
            amountRedeemed += currRedemption;

            emit Donated(currDepositor, recipient_, currRedemption);

            if (depositInfo[receiptIds[currIndex]].principalAmount == 0) {
                _closeDeposit(receiptIds[currIndex], currDepositor);

                if (currIndex != receiptIds.length - 1) {
                    receiptIds[currIndex] = receiptIds[receiptIds.length - 1]; // Delete integer from array by swapping with last element and calling pop()
                }

                delete recipientLookup[receiptIds[currIndex]];
                receiptIds.pop();
            }
        }

        emit Redeemed(recipient_, amountRedeemed);
    }

    /************************
     * Emergency Functions
     ************************/

    function emergencyShutdown(bool active_) external onlyGovernor {
        depositDisabled = active_;
        withdrawDisabled = active_;
        redeemDisabled = active_;
        emit EmergencyShutdown(active_);
    }

    function disableDeposits(bool active_) external onlyGovernor {
        depositDisabled = active_;
    }

    function disableWithdrawals(bool active_) external onlyGovernor {
        withdrawDisabled = active_;
    }

    function disableRedeems(bool active_) external onlyGovernor {
        redeemDisabled = active_;
    }
}
