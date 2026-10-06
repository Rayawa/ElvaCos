import { deviceInfo } from '@kit.BasicServicesKit';
export const SUPPORTS_HARMONY_API_23: boolean = deviceInfo.sdkApiVersion >= 23 && deviceInfo.distributionOSApiVersion >= 60100;
export const HDS_MATERIAL_TYPE_ADAPTIVE: number = 100;
export const HDS_MATERIAL_LEVEL_GENTLE: number = 1;
export const HDS_TITLE_SIZE_SMALL: number = 0;
