// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import '..//interfaces/IMarketPair.sol';

import "@openzeppelin/contracts/utils/math/SafeMath.sol";


library MarketLibrary {
    using SafeMath for uint;

    

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'MarketLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'MarketLibrary: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
        return amountB;
    }

    
}

