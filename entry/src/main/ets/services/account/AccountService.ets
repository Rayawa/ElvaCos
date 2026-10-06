import { authentication } from '@kit.AccountKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { HuaweiAccount } from '../../model/Entities';

/** 登录结果：UI 只根据 ok/message 展示，不解析任何令牌。 */
export class AccountResult {
  ok: boolean = false;
  account: HuaweiAccount = new HuaweiAccount();
  message: string = '';
}

/**
 * 华为账号（HUAWEI ID）登录适配。
 *
 * 只使用 Account Kit 的登录/取消授权能力，换取本机可离线使用的 OpenID / UnionID，
 * 不保存 authorizationCode、idToken 等临时凭据，也不请求任何用户资料权限。
 * 未在 AGC 开通 Account Kit 或未配置 client_id 时，系统会返回
 * 1001500001（应用指纹校验失败）等错误，这里统一转成可读提示。
 */
export class AccountService {
  static supported(): boolean {
    return canIUse('SystemCapability.AuthenticationServices.HuaweiID.Auth');
  }

  private message(error: BusinessError): string {
    switch (error.code) {
      case authentication.AuthenticationErrorCode.USER_CANCELED:
        return '已取消华为账号登录';
      case authentication.AuthenticationErrorCode.ACCOUNT_NOT_LOGGED_IN:
        return '本机尚未登录华为账号，请先在系统设置中登录后重试';
      case authentication.AuthenticationErrorCode.NETWORK_ERROR:
        return '网络不可用，请检查网络后重试';
      case authentication.AuthenticationErrorCode.PACKAGE_FINGERPRINT_CHECK_ERROR:
        return '华为账号服务未就绪：请在 AppGallery Connect 为当前包名和签名开通 Account Kit';
      case authentication.AuthenticationErrorCode.DUPLICATE_REQUEST_REJECTED:
        return '登录请求正在处理中，请稍候';
      case authentication.AuthenticationErrorCode.REQUEST_RESTRICTED:
        return '当前设备或账号不支持华为账号登录';
      case authentication.AuthenticationErrorCode.UNSUPPORTED:
        return '当前系统版本不支持华为账号登录';
      default:
        return `华为账号登录未完成（错误码 ${error.code}）`;
    }
  }

  /** 拉起华为账号登录，成功后返回可离线保存的身份标识。 */
  async signIn(context: common.UIAbilityContext): Promise<AccountResult> {
    const result = new AccountResult();
    if (!AccountService.supported()) {
      result.message = '当前设备不支持华为账号登录';
      return result;
    }
    try {
      const provider = new authentication.HuaweiIDProvider();
      const request = provider.createLoginWithHuaweiIDRequest();
      request.forceLogin = true;
      request.state = 'elvacos-signin';
      const controller = new authentication.AuthenticationController(context);
      const response = (await controller.executeRequest(request)) as authentication.LoginWithHuaweiIDResponse;
      const credential = response.data;
      if (!credential || !credential.openID) {
        result.message = '未取得华为账号标识，请重试';
        return result;
      }
      result.ok = true;
      result.account.signedIn = true;
      result.account.openId = credential.openID;
      result.account.unionId = credential.unionID || '';
      result.account.displayName = this.displayName(credential.openID);
      result.account.signedAt = Date.now();
      result.message = '已登录华为账号';
      return result;
    } catch (error) {
      const businessError = error as BusinessError;
      console.error('[ElvaCos][services/account/AccountService][ERROR]',
        `华为账号登录失败. Code: ${businessError.code}, message: ${businessError.message}`);
      result.message = this.message(businessError);
      return result;
    }
  }

  /** 撤销本应用对当前华为账号的授权，并清除本机登录态。 */
  async signOut(context: common.UIAbilityContext): Promise<AccountResult> {
    const result = new AccountResult();
    if (!AccountService.supported()) {
      result.ok = true;
      result.message = '已退出登录';
      return result;
    }
    try {
      const provider = new authentication.HuaweiIDProvider();
      const request = provider.createCancelAuthorizationRequest();
      request.state = 'elvacos-signout';
      const controller = new authentication.AuthenticationController(context);
      await controller.executeRequest(request);
      result.ok = true;
      result.message = '已退出华为账号';
      return result;
    } catch (error) {
      const businessError = error as BusinessError;
      console.error('[ElvaCos][services/account/AccountService][ERROR]',
        `退出华为账号失败. Code: ${businessError.code}, message: ${businessError.message}`);
      result.message = this.message(businessError);
      return result;
    }
  }

  /** 只用 OpenID 的尾部做本机展示，避免在界面上完整暴露身份标识。 */
  private displayName(openId: string): string {
    if (openId.length <= 4) {
      return '华为账号';
    }
    return '华为账号 ' + openId.slice(openId.length - 4);
  }
}
