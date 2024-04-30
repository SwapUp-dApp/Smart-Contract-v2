pragma solidity ^0.8.4;

contract SwapUp {
    uint data;

    function updateData(uint _data) external  {
        data = _data;
    }

    function readData() external view returns(uint)  {
        return data;
    }
}
