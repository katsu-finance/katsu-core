// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import '../../dependencies/pyth/PythStructs.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {IPoolAddressesProvider} from '../../interfaces/IPoolAddressesProvider.sol';
import {Errors} from '../../protocol/libraries/helpers/Errors.sol';

contract MockPyth {
  IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

  mapping(bytes32 => int64) private _latestPrices;

  event PriceUpdated(int256 indexed current, bytes32 indexed asset);

  constructor(
    IPoolAddressesProvider provider,
    bytes32[] memory priceIds,
    int64[] memory latestPrices
  ) {
    ADDRESSES_PROVIDER = provider;
    for (uint i = 0; i < priceIds.length; i++) {
      _latestPrices[priceIds[i]] = latestPrices[i];
      emit PriceUpdated(latestPrices[i], priceIds[i]);
    }
  }

  modifier onlyAssetListingOrPoolAdmins() {
    _onlyAssetListingOrPoolAdmins();
    _;
  }

  function addTokenPrices(
    bytes32[] memory priceIds,
    int64[] memory latestPrices
  ) external onlyAssetListingOrPoolAdmins {
    for (uint i = 0; i < priceIds.length; i++) {
      _latestPrices[priceIds[i]] = latestPrices[i];
      emit PriceUpdated(latestPrices[i], priceIds[i]);
    }
  }

  function getPriceNoOlderThan(
    bytes32 priceId,
    uint256 age
  ) external view returns (PythStructs.Price memory price) {
    return PythStructs.Price(_latestPrices[priceId], 0, 8, 0);
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

  function _onlyAssetListingOrPoolAdmins() internal view {
    IACLManager aclManager = IACLManager(ADDRESSES_PROVIDER.getACLManager());
    require(
      aclManager.isAssetListingAdmin(msg.sender) || aclManager.isPoolAdmin(msg.sender),
      Errors.CALLER_NOT_ASSET_LISTING_OR_POOL_ADMIN
    );
  }
}
