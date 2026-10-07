import { deviceInfo } from '@kit.BasicServicesKit';

/**
 * 设备信息汇总，供开发者选项展示（字段与 Dashboard 的完整设备信息结构一致）。
 *
 * deviceInfo.chipType 从 API 21 提供、performanceClass 从 API 19 提供；本工程最低兼容 API 23，
 * 仍按 Dashboard 的方式保留版本判断，低版本取值时退化为 unknown。
 */
function resolveChipType(): string {
  return deviceInfo.sdkApiVersion >= 21 ? deviceInfo.chipType : 'unknown';
}

export const DEVICE_CHIP_TYPE: string = resolveChipType();

export class FullDeviceInfo {
  public device_type: string = deviceInfo.deviceType;
  public manufacture: string = deviceInfo.manufacture;
  public brand: string = deviceInfo.brand;
  public market_name: string = deviceInfo.marketName;
  public product_series: string = deviceInfo.productSeries;
  public product_model: string = deviceInfo.productModel;
  public product_model_alias: string = deviceInfo.productModelAlias;
  public software_model: string = deviceInfo.softwareModel;
  public hardware_model: string = deviceInfo.hardwareModel;
  public bootloader_version: string = deviceInfo.bootloaderVersion;
  public abi_list: string = deviceInfo.abiList;
  public security_patch_tag: string = deviceInfo.securityPatchTag;
  public display_version: string = deviceInfo.displayVersion;
  public incremental_version: string = deviceInfo.incrementalVersion;
  public os_release_type: string = deviceInfo.osReleaseType;
  public os_full_name: string = deviceInfo.osFullName;
  public sdk_api_version: number = deviceInfo.sdkApiVersion;
  public first_api_version: number = deviceInfo.firstApiVersion;
  public version_id: string = deviceInfo.versionId;
  public build_type: string = deviceInfo.buildType;
  public build_user: string = deviceInfo.buildUser;
  public build_host: string = deviceInfo.buildHost;
  public build_time: string = deviceInfo.buildTime;
  public build_root_hash: string = deviceInfo.buildRootHash;
  public distribution_os_name: string = deviceInfo.distributionOSName;
  public distribution_os_version: string = deviceInfo.distributionOSVersion;
  public distribution_os_api_version: number = deviceInfo.distributionOSApiVersion;
  public distribution_os_api_name: string = deviceInfo.distributionOSApiName;
  public distribution_os_release_type: string = deviceInfo.distributionOSReleaseType;
  public performance_class: string = deviceInfo.performanceClass.toString();
  public chip_type: string = DEVICE_CHIP_TYPE;
}

/** 开发者选项的一行只读信息。 */
export interface DeviceInfoEntry {
  label: string;
  value: string;
}

function orDash(value: string): string { return value && value.length > 0 ? value : '-'; }

/** 性能等级是数字枚举：0 高、1 中、2 低。 */
function performanceLabel(level: number): string {
  if (level === 0) { return '高'; }
  if (level === 1) { return '中'; }
  if (level === 2) { return '低'; }
  return '未知';
}

/** 完整字段列表：设备信息整份展示，含空值兜底，避免长值在界面上被截断或挤爆。 */
export function deviceInfoEntries(): DeviceInfoEntry[] {
  const info = new FullDeviceInfo();
  return [
    { label: '设备类型', value: orDash(info.device_type) },
    { label: '厂商', value: orDash(info.manufacture) },
    { label: '品牌', value: orDash(info.brand) },
    { label: '市场名称', value: orDash(info.market_name) },
    { label: '产品系列', value: orDash(info.product_series) },
    { label: '产品型号', value: orDash(info.product_model) },
    { label: '产品型号别名', value: orDash(info.product_model_alias) },
    { label: '软件型号', value: orDash(info.software_model) },
    { label: '硬件型号', value: orDash(info.hardware_model) },
    { label: 'Bootloader 版本', value: orDash(info.bootloader_version) },
    { label: 'ABI 列表', value: orDash(info.abi_list) },
    { label: '安全补丁', value: orDash(info.security_patch_tag) },
    { label: '显示版本', value: orDash(info.display_version) },
    { label: '增量版本', value: orDash(info.incremental_version) },
    { label: '系统发布类型', value: orDash(info.os_release_type) },
    { label: '系统全名', value: orDash(info.os_full_name) },
    { label: 'SDK API 版本', value: String(info.sdk_api_version) },
    { label: '首个 API 版本', value: String(info.first_api_version) },
    { label: '版本 ID', value: orDash(info.version_id) },
    { label: '构建类型', value: orDash(info.build_type) },
    { label: '构建用户', value: orDash(info.build_user) },
    { label: '构建主机', value: orDash(info.build_host) },
    { label: '构建时间', value: orDash(info.build_time) },
    { label: '构建根哈希', value: orDash(info.build_root_hash) },
    { label: '发行版名称', value: orDash(info.distribution_os_name) },
    { label: '发行版版本', value: orDash(info.distribution_os_version) },
    { label: '发行版 API 版本', value: String(info.distribution_os_api_version) },
    { label: '发行版 API 名称', value: orDash(info.distribution_os_api_name) },
    { label: '发行版发布类型', value: orDash(info.distribution_os_release_type) },
    { label: '性能等级', value: performanceLabel(deviceInfo.performanceClass) },
    { label: '芯片型号', value: orDash(info.chip_type) },
  ];
}
