// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.7.5;

import '../interfaces/IERC20.sol';
import '../interfaces/IPair.sol';

import '../types/Ownable.sol';
import '../types/ERC20.sol';

import '../libraries/SafeMath.sol';
import '../libraries/Math.sol';
import '../libraries/SafeERC20.sol';

interface ITreasury {
    function deposit(
        uint256 _amount,
        address _token,
        uint256 _profit
    ) external returns (uint256 send_);

    function valueOfToken(address _token, uint256 _amount)
        external
        view
        returns (uint256 value_);
}

interface IStaking {
    function stake(uint256 _amount, address _recipient) external returns (bool);
}

contract CunoroNoroIDO is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public NORO;
    address public MAI;
    address public addressToSendMAI;
    address public maiNoroLP;
    address public staking;

    uint256 public totalAmount;
    uint256 public salePrice;
    uint256 public openPrice;
    uint256 public totalWhiteListed;
    uint256 public startOfSale;
    uint256 public endOfSale;

    bool public initialized;
    bool public whiteListEnabled;
    bool public cancelled;
    bool public finalized;

    mapping(address => bool) public boughtNORO;
    mapping(address => bool) public whiteListed;

    address[] buyers;
    mapping(address => uint256) public purchasedAmounts;

    address treasury;

    constructor(
        address _NORO,
        address _MAI,
        address _treasury,
        address _staking,
        address _maiNoroLP
    ) {
        require(_NORO != address(0));
        require(_MAI != address(0));
        require(_treasury != address(0));
        require(_staking != address(0));
        require(_maiNoroLP != address(0));

        NORO = _NORO;
        MAI = _MAI;
        treasury = _treasury;
        maiNoroLP = _maiNoroLP;
        staking = _staking;
        cancelled = false;
        finalized = false;
    }

    function saleStarted() public view returns (bool) {
        return initialized && startOfSale <= block.timestamp;
    }

    function whiteListBuyers(address[] memory _buyers)
        external
        onlyOwner
        returns (bool)
    {
        require(saleStarted() == false, 'Already started');

        totalWhiteListed = totalWhiteListed.add(_buyers.length);

        for (uint256 i; i < _buyers.length; i++) {
            whiteListed[_buyers[i]] = true;
        }

        return true;
    }

    function initialize(
        uint256 _totalAmount,
        uint256 _salePrice,
        uint256 _saleLength,
        uint256 _startOfSale
    ) external onlyOwner returns (bool) {
        require(initialized == false, 'Already initialized');
        initialized = true;
        whiteListEnabled = true;
        totalAmount = _totalAmount;
        salePrice = _salePrice;
        startOfSale = _startOfSale;
        endOfSale = _startOfSale.add(_saleLength);
        return true;
    }

    function getAllotmentPerBuyer() public view returns (uint256) {
        if (whiteListEnabled) {
            return totalAmount.div(totalWhiteListed);
        } else {
            return Math.min(200 * 1e9, totalAmount);
        }
    }

    function purchaseNORO(uint256 _amountMAI) external returns (bool) {
        require(saleStarted() == true, 'Not started');
        require(
            !whiteListEnabled || whiteListed[msg.sender] == true,
            'Not whitelisted'
        );
        require(boughtNORO[msg.sender] == false, 'Already participated');

        boughtNORO[msg.sender] = true;

        uint256 _purchaseAmount = _calculateSaleQuote(_amountMAI);

        require(_purchaseAmount <= getAllotmentPerBuyer(), 'More than alloted');
        if (whiteListEnabled) {
            totalWhiteListed = totalWhiteListed.sub(1);
        }

        totalAmount = totalAmount.sub(_purchaseAmount);

        purchasedAmounts[msg.sender] = _purchaseAmount;
        buyers.push(msg.sender);

        IERC20(MAI).safeTransferFrom(msg.sender, address(this), _amountMAI);

        return true;
    }

    function disableWhiteList() external onlyOwner {
        whiteListEnabled = false;
    }

    function _calculateSaleQuote(uint256 paymentAmount_)
        internal
        view
        returns (uint256)
    {
        return uint256(1e9).mul(paymentAmount_).div(salePrice);
    }

    function calculateSaleQuote(uint256 paymentAmount_)
        external
        view
        returns (uint256)
    {
        return _calculateSaleQuote(paymentAmount_);
    }

    /// @dev Only Emergency Use
    /// cancel the IDO and return the funds to all buyer
    function cancel() external onlyOwner {
        cancelled = true;
        startOfSale = 99999999999;
    }

    function withdraw() external {
        require(cancelled, 'ido is not cancelled');
        uint256 amount = purchasedAmounts[msg.sender];
        IERC20(MAI).transfer(msg.sender, (amount / 1e9) * salePrice);
    }

    function claim(address _recipient) public {
        require(finalized, 'only can claim after finalized');
        require(purchasedAmounts[_recipient] > 0, 'not purchased');
        IStaking(staking).stake(purchasedAmounts[_recipient], _recipient);
        purchasedAmounts[_recipient] = 0;
    }

    function finalize(address _receipt) external onlyOwner {
        require(totalAmount == 0, 'need all noros to be sold');

        uint256 maiInTreasure = 250000 * 1e18;

        IERC20(MAI).approve(treasury, maiInTreasure);
        uint256 noroMinted = ITreasury(treasury).deposit(maiInTreasure, MAI, 0);

        require(noroMinted == 250000 * 1e9);

        // dev: create lp with 15 MAI per NORO
        IERC20(MAI).transfer(maiNoroLP, 750000 * 1e18);
        IERC20(NORO).transfer(maiNoroLP, 50000 * 1e9);
        uint256 lpBalance = IPair(maiNoroLP).mint(address(this));
        uint256 valueOfToken = ITreasury(treasury).valueOfToken(
            maiNoroLP,
            lpBalance
        );

        IPair(maiNoroLP).approve(treasury, lpBalance);
        uint256 zeroMinted = ITreasury(treasury).deposit(
            lpBalance,
            maiNoroLP,
            valueOfToken
        );
        require(zeroMinted == 0, 'should not mint any NORO');
        IERC20(NORO).approve(staking, noroMinted);

        finalized = true;

        claim(_receipt);
    }
}
