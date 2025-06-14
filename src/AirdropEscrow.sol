// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AirdropEscrow{
    enum ClaimStatus { Pending, Accepted, Rejected }

    struct Offer {
        bytes32 merkleRoot;
        address consumer;
        uint256 totalStaked;
        uint256 deadline;
        uint256 minAccepts;
        uint256 totalAccepted;
        uint256 totalRejected;
        bool finalized;
        mapping(address => ClaimStatus) claims;
        mapping(address => uint256) allocations;
    }

    IERC20 public immutable stablecoin;
    uint256 public offerCounter;
    mapping(uint256 => Offer) private offers;

    event OfferCreated(
        uint256 indexed offerId,
        address indexed consumer,
        uint256 totalStaked,
        uint256 minAccepts,
        uint256 deadline
    );

    event ParticipantClaimed(
        uint256 indexed offerId,
        address indexed participant,
        uint256 amount,
        ClaimStatus status
    );

    event OfferFinalized(
        uint256 indexed offerId,
        address indexed consumer,
        bool success,
        uint256 totalAccepted,
        uint256 refundedAmount
    );

    event OfferCancelled(
        uint256 indexed offerId,
        address indexed consumer,
        uint256 refundedAmount
    );

    constructor(address _stablecoin) {
        stablecoin = IERC20(_stablecoin);
    }

    function createOffer(
        bytes32 merkleRoot,
        uint256 totalStaked,
        uint256 minAccepts,
        uint256 deadline
    ) external returns (uint256) {
        require(deadline > block.timestamp, "Deadline must be future");
        require(minAccepts > 0, "Must require at least one accept");

        offerCounter++;
        Offer storage offer = offers[offerCounter];
        offer.merkleRoot = merkleRoot;
        offer.consumer = msg.sender;
        offer.totalStaked = totalStaked;
        offer.deadline = deadline;
        offer.minAccepts = minAccepts;

        require(stablecoin.transferFrom(msg.sender, address(this), totalStaked), "Stake failed");

        emit OfferCreated(offerCounter, msg.sender, totalStaked, minAccepts, deadline);
        return offerCounter;
    }

    function claim(
        uint256 offerId,
        uint256 amount,
        ClaimStatus status,
        bytes32[] calldata proof
    ) external {
        Offer storage offer = offers[offerId];
        require(!offer.finalized, "Offer finalized");
        require(block.timestamp <= offer.deadline, "Claim period over");
        require(status == ClaimStatus.Accepted || status == ClaimStatus.Rejected, "Invalid status");
        require(offer.claims[msg.sender] == ClaimStatus.Pending, "Already claimed");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        require(MerkleProof.verify(proof, offer.merkleRoot, leaf), "Invalid proof");

        offer.claims[msg.sender] = status;
        offer.allocations[msg.sender] = amount;

        if (status == ClaimStatus.Accepted) {
            offer.totalAccepted += amount;
            require(stablecoin.transfer(msg.sender, amount), "Transfer failed");
        } else if (status == ClaimStatus.Rejected) {
            offer.totalRejected += amount;
            // tokens remain escrowed
        }

        emit ParticipantClaimed(offerId, msg.sender, amount, status);
    }

    function finalize(uint256 offerId) external {
        Offer storage offer = offers[offerId];
        require(msg.sender == offer.consumer, "Only consumer");
        require(!offer.finalized, "Already finalized");
        require(block.timestamp > offer.deadline, "Deadline not reached");

        uint256 refundedAmount = 0;

        if (offer.totalAccepted >= offer.minAccepts) {
            refundedAmount = offer.totalStaked - offer.totalAccepted;
            if (refundedAmount > 0) {
                require(stablecoin.transfer(offer.consumer, refundedAmount), "Refund failed");
            }
            offer.finalized = true;
            emit OfferFinalized(offerId, msg.sender, true, offer.totalAccepted, refundedAmount);
        } else {
            revert("Not enough accepts, call cancel");
        }
    }

    function cancel(uint256 offerId) external {
        Offer storage offer = offers[offerId];
        require(msg.sender == offer.consumer, "Only consumer");
        require(!offer.finalized, "Already finalized");

        uint256 acceptedAmount = offer.totalAccepted;
        uint256 refundAmount = offer.totalStaked - acceptedAmount;

        if (refundAmount > 0) {
            require(stablecoin.transfer(offer.consumer, refundAmount), "Refund failed");
        }

        offer.finalized = true;
        emit OfferCancelled(offerId, msg.sender, refundAmount);
    }

    function getClaimStatus(uint256 offerId, address participant) external view returns (ClaimStatus) {
        return offers[offerId].claims[participant];
    }
}
