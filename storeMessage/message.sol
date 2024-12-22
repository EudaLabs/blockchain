
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract HashedMessageStorage {
    struct Message {
        address messageSender;
        address messageReceiver;
        bytes32 messageHash;
    }
    
    Message[] private messages;
    
    event MessageStored(
        address indexed messageSender,
        address indexed messageReceiver,
        bytes32 messageHash
    );
    
    function storeMessage(
        address _messageReceiver,
        bytes32 _messageHash
    ) public {
        Message memory newMessage = Message({
            messageSender: msg.sender,
            messageReceiver: _messageReceiver,
            messageHash: _messageHash
        });
        
        messages.push(newMessage);
        
        emit MessageStored(
            msg.sender,
            _messageReceiver,
            _messageHash
        );
    }
    
    function getMessage(uint256 _index) public view returns (
        address messageSender,
        address messageReceiver,
        bytes32 messageHash
    ) {
        require(_index < messages.length, "Index out of bounds");
        Message memory message = messages[_index];
        return (
            message.messageSender,
            message.messageReceiver,
            message.messageHash
        );
    }
    
    function getAllMessages() public view returns (Message[] memory) {
        return messages;
    }
    
    function getMessageCount() public view returns (uint256) {
        return messages.length;
    }

    // Get all hashes sent by a specific address
    function getHashesBySender(address _sender) public view returns (bytes32[] memory) {
        uint count = 0;
        for (uint i = 0; i < messages.length; i++) {
            if (messages[i].messageSender == _sender) {
                count++;
            }
        }
        
        bytes32[] memory hashes = new bytes32[](count);
        uint index = 0;
        
        for (uint i = 0; i < messages.length; i++) {
            if (messages[i].messageSender == _sender) {
                hashes[index] = messages[i].messageHash;
                index++;
            }
        }
        
        return hashes;
    }
    
    // Get all hashes sent to a specific address
    function getHashesByReceiver(address _receiver) public view returns (bytes32[] memory) {
        uint count = 0;
        for (uint i = 0; i < messages.length; i++) {
            if (messages[i].messageReceiver == _receiver) {
                count++;
            }
        }
        
        bytes32[] memory hashes = new bytes32[](count);
        uint index = 0;
        
        for (uint i = 0; i < messages.length; i++) {
            if (messages[i].messageReceiver == _receiver) {
                hashes[index] = messages[i].messageHash;
                index++;
            }
        }
        
        return hashes;
    }
}