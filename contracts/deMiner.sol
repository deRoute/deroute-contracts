// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./common/NonReentrancy.sol";


contract deMiner is NonReentrancy, Ownable {

    using SafeERC20 for IERC20;

    uint256 constant INITIAL_REWARD_PER_REPORT = 90e18;
    uint256 constant INITIAL_EXTRA_REWARD_PER_REPORT = 10e18;

    uint256 constant REPORT_WAIT_BLOCK = 100;

    IERC20 public deRouteToken;

    // Keeps track of all miners.
    address[] public minerArray;
    mapping(address => uint256) public minerIndexPlusOne;
    mapping(address => uint256) public minerCollateralMap;

    uint256 public latestRewardBlock;
    uint256 public currentRound;

    // N size: how many nodes check connectivity of each other.
    uint256 public nSize = 10;

    struct ConnectivityReport {
        address who;
        bool connected;
    }

    // Tracks the count of peers reporting certain address not connected.
    //
    // round => who => count
    mapping(uint256 => mapping(address => uint256)) public notConnectedCount;
    // round => who[]
    mapping(uint256 => address[]) public reportedPeers;

    event ReportNotConnected(uint256 indexed round_, address who_);

    constructor(IERC20 deRouteToken_) Ownable(msg.sender) {
        deRouteToken = deRouteToken_;
    }

    function setNSize(uint256 nSize_) external onlyOwner {
        nSize = nSize_;
    }

    function getRewardPerReport() public view returns(uint256) {
        // Halves every 1 million report.
        uint256 divider = 2 ** (currentRound / 1e6);
        return INITIAL_REWARD_PER_REPORT / divider;
    }

    function getExtraRewardPerReport() public view returns(uint256) {
        // Halves every 1 million report.
        uint256 divider = 2 ** (currentRound / 1e6);
        return INITIAL_EXTRA_REWARD_PER_REPORT / divider;
    }

    // To register a miner.
    function register() external noReenter {
        require(minerIndexPlusOne[msg.sender] == 0, "already registered");

        uint256 collateralAmount = getRewardPerReport() * 10;
        deRouteToken.safeTransferFrom(msg.sender, address(this), collateralAmount);
        minerCollateralMap[msg.sender] = collateralAmount;

        // Adds miner into the array.
        minerArray.push(msg.sender);
        minerIndexPlusOne[msg.sender] = minerArray.length;
    }

    // To unregister a miner.
    function unregister() external noReenter {
        require(minerIndexPlusOne[msg.sender] > 0, "not registered");

        // Returns collateral.
        deRouteToken.safeTransfer(msg.sender, minerCollateralMap[msg.sender]);
        minerCollateralMap[msg.sender] = 0;

        // Removes miner from array.
        if (minerIndexPlusOne[msg.sender] < minerArray.length) {
            address lastMiner = minerArray[minerArray.length - 1];
            minerArray[minerIndexPlusOne[msg.sender] - 1] = lastMiner;
            minerIndexPlusOne[lastMiner] = minerIndexPlusOne[msg.sender];
        }

        minerIndexPlusOne[msg.sender] = 0;
        minerArray.pop();
    }

    // Get an array of size n of random selected peers.
    function getSelectedPeers() public view returns(address[] memory) {
        address[] memory result = new address[](nSize);
        // TODO: Finish the algorithm here.
        return result;
    }

    // N random nodes are selected to report connectivity of each other.
    //
    // If more than 50% of the N nodes report that certain nodes are not
    // connected, the corresponding nodes will be reported to the DAO for
    // arbitration.
    function reportConnectivity(ConnectivityReport[] memory reportArray_) external {
        require(reportArray_.length + 1 == nSize, "report n - 1");

        uint256 i;

        if (block.number > latestRewardBlock + REPORT_WAIT_BLOCK) {
            // Reward the previous round reporters.
            uint256 amount = getRewardPerReport() / reportedPeers[currentRound].length;

            for (i = 0; i < reportedPeers[currentRound].length; ++i) {
                deRouteToken.safeTransfer(reportedPeers[currentRound][i], amount);
            }

            // Check if any of the selected peers are not connected.
            address[] memory lastRoundPeers = getSelectedPeers();
            for (i = 0; i < lastRoundPeers.length; ++i) {
                if (notConnectedCount[currentRound][lastRoundPeers[i]] > nSize / 2) {
                    emit ReportNotConnected(currentRound, lastRoundPeers[i]);
                }
            }

            // A new round starts now.
            latestRewardBlock = block.number;
            ++currentRound;

            // As the first reporter, earns extra reward.
            uint256 extraAmount = getExtraRewardPerReport();
            deRouteToken.safeTransfer(msg.sender, extraAmount);
        }

        for (i = 0; i < reportArray_.length; ++i) {
            if (!reportArray_[i].connected) {
                ++notConnectedCount[currentRound][reportArray_[i].who];
            }
        }
    }
}
