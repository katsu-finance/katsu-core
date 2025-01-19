// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IFallbackOracle {
  function getPriceId(address _asset) external view returns (bytes32 priceId);

  function getAssetPrice(address _asset) external view returns (uint256 price);

  function getDecimals(address _asset) external view returns (uint8 decimals);

  function getAssetPriceAndDecimals(
    address _asset
  ) external view returns (uint256 price, uint8 decimals);

  function getPyth() external view returns (address);
}
