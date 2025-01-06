// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IPyth} from '../dependencies/pyth/IPyth.sol';
import {PythStructs} from '../dependencies/pyth/PythStructs.sol';
import {Errors} from '../protocol/libraries/helpers/Errors.sol';
import {IACLManager} from '../interfaces/IACLManager.sol';
import {IPoolAddressesProvider} from '../interfaces/IPoolAddressesProvider.sol';
import {IPriceOracleGetter} from '../interfaces/IPriceOracleGetter.sol';
import {IAaveOracle} from '../interfaces/IAaveOracle.sol';
import {console} from 'hardhat/console.sol';

/**
 * @title AaveOracle
 * @author Aave
 * @notice Contract to get asset prices, manage price sources and update the fallback oracle
 * - Use of Chainlink Aggregators as first source of price
 * - If the returned price by a Chainlink aggregator is <= 0, the call is forwarded to a fallback oracle
 * - Owned by the Aave governance
 */
contract AaveOracle is IAaveOracle {
  IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

  IPyth public pyth;

  // Map of asset price priceId (asset => priceId)
  mapping(address => bytes32) private assetsPriceIds;

  IPriceOracleGetter private _fallbackOracle;
  address public immutable override BASE_CURRENCY;
  uint256 public immutable override BASE_CURRENCY_UNIT;

  /**
   * @dev Only asset listing or pool admin can call functions marked by this modifier.
   */
  modifier onlyAssetListingOrPoolAdmins() {
    _onlyAssetListingOrPoolAdmins();
    _;
  }

  /**
   * @notice Constructor
   * @param provider The address of the new PoolAddressesProvider
   * @param assets The addresses of the assets
   * @param priceIds The priceId of the asset
   * @param fallbackOracle The address of the fallback oracle to use if the data of an
   *        aggregator is not consistent
   * @param baseCurrency The base currency used for the price quotes. If USD is used, base currency is 0x0
   * @param baseCurrencyUnit The unit of the base currency
   */
  constructor(
    IPoolAddressesProvider provider,
    address[] memory assets,
    bytes32[] memory priceIds,
    IPyth pythAddress,
    address fallbackOracle,
    address baseCurrency,
    uint256 baseCurrencyUnit
  ) {
    ADDRESSES_PROVIDER = provider;
    pyth = pythAddress;
    _setFallbackOracle(fallbackOracle);
    _setAssetsPriceId(assets, priceIds);
    BASE_CURRENCY = baseCurrency;
    BASE_CURRENCY_UNIT = baseCurrencyUnit;
    emit BaseCurrencySet(baseCurrency, baseCurrencyUnit);
  }

  /// @inheritdoc IAaveOracle
  function setFallbackOracle(
    address fallbackOracle
  ) external override onlyAssetListingOrPoolAdmins {
    _setFallbackOracle(fallbackOracle);
  }

  function setAssetsPriceIds(
    address[] calldata assets,
    bytes32[] memory priceIds
  ) external override onlyAssetListingOrPoolAdmins {
    _setAssetsPriceId(assets, priceIds);
  }

  function _setAssetsPriceId(address[] memory assets, bytes32[] memory priceIds) internal {
    require(assets.length == priceIds.length, Errors.INCONSISTENT_PARAMS_LENGTH);
    for (uint256 i = 0; i < assets.length; i++) {
      assetsPriceIds[assets[i]] = priceIds[i];
      emit AssetPriceIdUpdated(assets[i], priceIds[i]);
    }
  }

  /**
   * @notice Internal function to set the fallback oracle
   * @param fallbackOracle The address of the fallback oracle
   */
  function _setFallbackOracle(address fallbackOracle) internal {
    _fallbackOracle = IPriceOracleGetter(fallbackOracle);
    emit FallbackOracleUpdated(fallbackOracle);
  }

  /// @inheritdoc IPriceOracleGetter
  function getAssetPrice(address asset) public view override returns (uint256) {
    bytes32 priceId = assetsPriceIds[asset];

    if (asset == BASE_CURRENCY) {
      return BASE_CURRENCY_UNIT;
    } else if (address(pyth) == address(0)) {
      return _fallbackOracle.getAssetPrice(asset);
    } else {
      PythStructs.Price memory currentBasePrice = pyth.getPriceNoOlderThan(priceId, 60);
      if (currentBasePrice.price >= 0) {
        return uint256(uint64(currentBasePrice.price));
      } else {
        return _fallbackOracle.getAssetPrice(asset);
      }
    }
  }

  /// @inheritdoc IAaveOracle
  function getAssetsPrices(
    address[] calldata assets
  ) external view override returns (uint256[] memory) {
    uint256[] memory prices = new uint256[](assets.length);
    for (uint256 i = 0; i < assets.length; i++) {
      prices[i] = getAssetPrice(assets[i]);
    }
    return prices;
  }

  // /// @inheritdoc IAaveOracle
  // function getSourceOfAsset(address asset) external view override returns (address) {
  //   return address(assetsSources[asset]);
  // }

  function getPriceIdOfAsset(address asset) external view override returns (bytes32) {
    return assetsPriceIds[asset];
  }

  /// @inheritdoc IAaveOracle
  function getFallbackOracle() external view returns (address) {
    return address(_fallbackOracle);
  }

  function getPyth() external view returns (address) {
    return address(pyth);
  }

  function _onlyAssetListingOrPoolAdmins() internal view {
    IACLManager aclManager = IACLManager(ADDRESSES_PROVIDER.getACLManager());
    require(
      aclManager.isAssetListingAdmin(msg.sender) || aclManager.isPoolAdmin(msg.sender),
      Errors.CALLER_NOT_ASSET_LISTING_OR_POOL_ADMIN
    );
  }
}
