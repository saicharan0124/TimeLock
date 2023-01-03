// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract TimeLock {
    error NotOwnerError();
    error AlreadyQueuedError(bytes32 txId);
    error TimestampNotInRangeError(uint blockTimestamp, uint timestamp);
    error NotQueuedError(bytes32 txId);
    error TimestampNotPassedError(uint blockTimestmap, uint timestamp);
    error TxFailedError();

    event Queue(
        bytes32 indexed txId,
        address indexed target,
        uint value,
        string func,
        bytes data,
        uint timestamp
    );
   
    event Cancel(bytes32 indexed txId);

    uint public constant MIN_DELAY = 10; // seconds
    uint public constant GRACE_PERIOD = 1000; // seconds

    address public owner;
    // tx id => queued
   
    struct queue_data{
        address _target;
        uint _value;
        string  _func;
        bytes  _data;
        uint DueTime;
        bool queue;
    }
        mapping(bytes32 => queue_data) public q_data;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwnerError();
        }
        _;
    }

    receive() external payable {}

    function getTxId(
        address _target,
        uint _value,
        string calldata _func,
        bytes calldata _data,
        uint _timestamp
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(_target, _value, _func, _data, _timestamp));
    }

   
    function queue(
        address _target,
        uint _value,
        string calldata _func,
        bytes calldata _data,
        uint MAX_DELAY
    ) external onlyOwner returns (bytes32 txId) {
        uint _timestamp=block.timestamp;
        txId = getTxId(_target, _value, _func, _data, _timestamp);
        if (q_data[txId].queue) {
            revert AlreadyQueuedError(txId);
        }
        
        if (
            _timestamp < block.timestamp + MIN_DELAY ||
            _timestamp > block.timestamp + MAX_DELAY
        ) {
            revert TimestampNotInRangeError(block.timestamp, _timestamp);
        }
         q_data[txId] = queue_data({
             _target:_target,
             _value:_value,
              _func:_func,
              _data:_data,
             DueTime:_timestamp+MAX_DELAY,
             queue:true
           
        });
       


        emit Queue(txId, _target, _value, _func, _data, _timestamp);
    }

    function execute(
        bytes32 txId
    ) external payable onlyOwner returns (bytes memory) {
      
        if (!q_data[txId].queue) {
            revert NotQueuedError(txId);
        }
        
        if (block.timestamp < q_data[txId].DueTime) {
            revert TimestampNotPassedError(block.timestamp, q_data[txId].DueTime);
        }
       
   

        // prepare data
        bytes memory data;
        if (bytes(q_data[txId]._func).length > 0) {
            // data = func selector + _data
            data = abi.encodePacked(bytes4(keccak256(bytes(q_data[txId]._func))),q_data[txId]._data);
        } else {
            // call fallback with data
            data = q_data[txId]._data;
        }

        // call target
        (bool ok, bytes memory res) = q_data[txId]._target.call{value: q_data[txId]._value}(data);
        if (!ok) {
            revert TxFailedError();
        }
        else{
                 q_data[txId].queue = false;
        }
      

        return res;
    }

    function cancel(bytes32 _txId) external onlyOwner {
        if (!q_data[_txId].queue) {
            revert NotQueuedError(_txId);
        }

        q_data[_txId].queue = false;

        emit Cancel(_txId);
    }
}
