//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.25;

contract MockChainLinkFeed {
    function latestRoundData()
        public
        view
        virtual
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            18446744073709581025,
            310050130000,
            1716198404,
            1716198404,
            18446744073709581025
        );
    }
}
