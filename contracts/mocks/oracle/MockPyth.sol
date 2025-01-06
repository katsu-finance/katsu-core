// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import '../../dependencies/pyth/PythStructs.sol';

contract MockPyth {
  mapping(bytes32 => int64) private _latestPrices;

  event PriceUpdated(int256 indexed current, bytes32 indexed asset);

  constructor(bytes32[] memory priceIds, int64[] memory latestPrices) {
    for (uint i = 0; i < priceIds.length; i++) {
      _latestPrices[priceIds[i]] = latestPrices[i];
      emit PriceUpdated(latestPrices[i], priceIds[i]);
    }
  }

  function getPriceNoOlderThan(
    bytes32 priceId,
    uint256 age
  ) external view returns (PythStructs.Price memory price) {
    return PythStructs.Price(_latestPrices[priceId], 0, 0, 0);
  }

  function updatePriceFeedsIfNecessary(
    bytes[] calldata updateData,
    bytes32[] calldata priceIds,
    uint64[] calldata publishTimes,
    int64[] calldata latestPrices
  ) external payable {
    for (uint i = 0; i < priceIds.length; i++) {
      _latestPrices[priceIds[i]] = latestPrices[i];
    }
  }

  function getUpdateFee(bytes[] calldata updateData) external pure returns (uint feeAmount) {
    return 10;
  }

  function getTokenType() external pure returns (uint256) {
    return 1;
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }
}
