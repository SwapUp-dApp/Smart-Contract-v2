// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EscrowDemo {
    struct EscrowStruct {
        address sender;
        address recipient;
        uint256 amount;
        bool isFunded;
        bool isReleased;
    }

    mapping(uint256 => EscrowStruct) public escrows;
    uint256 public escrowCount;
    address public escrowAgent;

    event EscrowCreated(
        uint256 escrowId,
        address indexed sender,
        address indexed recipient,
        uint256 amount
    );
    event Funded(uint256 escrowId, address indexed sender, uint256 amount);
    event Released(uint256 escrowId, address indexed recipient, uint256 amount);
    event Refunded(uint256 escrowId, address indexed sender, uint256 amount);

    modifier onlyEscrowAgent() {
        require(
            msg.sender == escrowAgent,
            'Only escrow agent can call this function.'
        );
        _;
    }

    modifier onlySender(uint256 escrowId) {
        require(
            msg.sender == escrows[escrowId].sender,
            'Only sender can call this function.'
        );
        _;
    }

    constructor(address _escrowAgent) {
        escrowAgent = _escrowAgent;
        escrowCount = 0;
    }

    function createEscrow(address _recipient) external returns (uint256) {
        escrows[escrowCount] = EscrowStruct({
            sender: msg.sender,
            recipient: _recipient,
            amount: 0,
            isFunded: false,
            isReleased: false
        });

        emit EscrowCreated(escrowCount, msg.sender, _recipient, 0);
        escrowCount++;
        return escrowCount - 1;
    }

    function fundEscrow(
        uint256 escrowId
    ) external payable onlySender(escrowId) {
        require(!escrows[escrowId].isFunded, 'Escrow is already funded.');
        require(msg.value > 0, 'Amount must be greater than 0.');

        escrows[escrowId].amount = msg.value;
        escrows[escrowId].isFunded = true;

        emit Funded(escrowId, msg.sender, msg.value);
    }

    function releaseFunds(uint256 escrowId) external onlyEscrowAgent {
        require(escrows[escrowId].isFunded, 'Escrow is not funded.');
        require(
            !escrows[escrowId].isReleased,
            'Funds have already been released.'
        );

        escrows[escrowId].isReleased = true;
        payable(escrows[escrowId].recipient).transfer(escrows[escrowId].amount);

        emit Released(
            escrowId,
            escrows[escrowId].recipient,
            escrows[escrowId].amount
        );
    }

    function refundFunds(uint256 escrowId) external onlyEscrowAgent {
        require(escrows[escrowId].isFunded, 'Escrow is not funded.');
        require(
            !escrows[escrowId].isReleased,
            'Funds have already been released.'
        );

        escrows[escrowId].isFunded = false;
        payable(escrows[escrowId].sender).transfer(escrows[escrowId].amount);

        emit Refunded(
            escrowId,
            escrows[escrowId].sender,
            escrows[escrowId].amount
        );
    }
}
