import { deviceInfo } from '@kit.BasicServicesKit';
// API 26 apiAvailable cannot be evaluated on API 20. Keep guards on old device fields.

export const SUPPORTS_API_21: boolean = deviceInfo.sdkApiVersion >= 21;

export const SUPPORTS_API_23: boolean = deviceInfo.sdkApiVersion >= 23 && deviceInfo.distributionOSApiVersion >= 60100;

export const SUPPORTS_API_24: boolean = deviceInfo.sdkApiVersion >= 24;

export const SUPPORTS_API_26: boolean = deviceInfo.sdkApiVersion >= 26;
// Stable SDK 26 values avoid resolving newer native enums during API 20 startup.

export const HDS_MATERIAL_NONE: number = 0;

export const HDS_MATERIAL_ADAPTIVE: number = 100;
