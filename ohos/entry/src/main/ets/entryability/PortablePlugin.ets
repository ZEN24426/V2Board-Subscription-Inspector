import {
  Any,
  FlutterPlugin,
  Log,
  MethodCall,
  MethodChannel
} from '@ohos/flutter_ohos';
import { MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { common, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'PortablePlugin';
const ALIAS_PATTERN = /^[A-Za-z0-9_]+$/;
const MAX_SECRET_BYTES = 1024;
const ASSET_NOT_FOUND = 24000002;
const ASSET_ALREADY_EXISTS = 24000003;

export default class PortablePlugin implements FlutterPlugin {
  private readonly context: common.UIAbilityContext;
  private channel?: MethodChannel;
  private readonly encoder: util.TextEncoder = new util.TextEncoder();
  private readonly decoder: util.TextDecoder = new util.TextDecoder('utf-8', { ignoreBOM: true });

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'feiniao/portable');
    const that = this;
    this.channel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult) {
        that.handleCall(call, result);
      }
    });
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
  }

  getUniqueClassName(): string {
    return 'PortablePlugin';
  }

  private async handleCall(call: MethodCall, result: MethodResult): Promise<void> {
    switch (call.method) {
      case 'storeSave':
        await this.handleStoreSave(call, result);
        break;
      case 'storeLoad':
        await this.handleStoreLoad(call, result);
        break;
      case 'storeRemove':
        await this.handleStoreRemove(call, result);
        break;
      case 'storeListIds':
        await this.handleStoreListIds(result);
        break;
      case 'openUrl':
        this.handleOpenUrl(call, result);
        break;
      case 'log':
        this.handleLog(call);
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private async handleStoreSave(call: MethodCall, result: MethodResult): Promise<void> {
    const id: string = call.argument('id');
    const secret: string = call.argument('secret');
    if (typeof id !== 'string' || typeof secret !== 'string') {
      result.error('ARG_ERROR', 'missing arguments', null);
      return;
    }
    if (!ALIAS_PATTERN.test(id)) {
      result.error('ARG_ERROR', '安全存储标识不合法', null);
      return;
    }
    try {
      const bytes = this.encoder.encodeInto(secret);
      if (bytes.length === 0 || bytes.length > MAX_SECRET_BYTES) {
        result.error('ARG_ERROR', '内容过长，无法存入系统安全存储', null);
        return;
      }
      const attributes: asset.AssetMap = new Map();
      attributes.set(asset.Tag.ALIAS, this.encoder.encodeInto(id));
      attributes.set(asset.Tag.SECRET, bytes);
      attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
      let needUpdate = false;
      try {
        await asset.add(attributes);
      } catch (addError) {
        const addBusinessError = addError as BusinessError;
        if (addBusinessError.code === ASSET_ALREADY_EXISTS) {
          needUpdate = true;
        } else {
          Log.e(TAG, `storeSave add failed: ${addBusinessError.code} ${addBusinessError.message}`);
          result.error('STORE_ERROR', addBusinessError.message, null);
          return;
        }
      }
      if (needUpdate) {
        const update: asset.AssetMap = new Map();
        update.set(asset.Tag.SECRET, bytes);
        await asset.update(this.aliasQuery(id), update);
      }
      result.success(null);
    } catch (error) {
      const businessError = error as BusinessError;
      Log.e(TAG, `storeSave failed: ${businessError.code} ${businessError.message}`);
      result.error('STORE_ERROR', businessError.message, null);
    }
  }

  private async handleStoreLoad(call: MethodCall, result: MethodResult): Promise<void> {
    const id: string = call.argument('id');
    if (typeof id !== 'string') {
      result.error('ARG_ERROR', 'missing arguments', null);
      return;
    }
    if (!ALIAS_PATTERN.test(id)) {
      result.success(null);
      return;
    }
    try {
      const query = this.aliasQuery(id);
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
      const assets = await asset.query(query);
      if (assets.length === 0) {
        result.success(null);
        return;
      }
      const secret = assets[0].get(asset.Tag.SECRET);
      if (secret === undefined || secret === null) {
        result.success(null);
        return;
      }
      result.success(this.decoder.decodeToString(secret as Uint8Array));
    } catch (error) {
      const businessError = error as BusinessError;
      if (businessError.code === ASSET_NOT_FOUND) {
        result.success(null);
        return;
      }
      Log.e(TAG, `storeLoad failed: ${businessError.code} ${businessError.message}`);
      result.error('STORE_ERROR', businessError.message, null);
    }
  }

  private async handleStoreRemove(call: MethodCall, result: MethodResult): Promise<void> {
    const id: string = call.argument('id');
    if (typeof id !== 'string') {
      result.error('ARG_ERROR', 'missing arguments', null);
      return;
    }
    if (!ALIAS_PATTERN.test(id)) {
      result.success(null);
      return;
    }
    try {
      await asset.remove(this.aliasQuery(id));
      result.success(null);
    } catch (error) {
      const businessError = error as BusinessError;
      if (businessError.code === ASSET_NOT_FOUND) {
        result.success(null);
        return;
      }
      Log.e(TAG, `storeRemove failed: ${businessError.code} ${businessError.message}`);
      result.error('STORE_ERROR', businessError.message, null);
    }
  }

  private async handleStoreListIds(result: MethodResult): Promise<void> {
    try {
      const query: asset.AssetMap = new Map();
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ATTRIBUTES);
      const assets = await asset.query(query);
      const ids: string[] = [];
      for (const item of assets) {
        const alias = item.get(asset.Tag.ALIAS);
        if (alias !== undefined && alias !== null) {
          ids.push(this.decoder.decodeToString(alias as Uint8Array));
        }
      }
      result.success(ids);
    } catch (error) {
      const businessError = error as BusinessError;
      if (businessError.code === ASSET_NOT_FOUND) {
        result.success([]);
        return;
      }
      Log.e(TAG, `storeListIds failed: ${businessError.code} ${businessError.message}`);
      result.error('STORE_ERROR', businessError.message, null);
    }
  }

  private handleOpenUrl(call: MethodCall, result: MethodResult): void {
    const url: string = call.argument('url');
    if (typeof url !== 'string' || !url.startsWith('https://')) {
      result.error('ARG_ERROR', '仅允许打开 HTTPS 链接', null);
      return;
    }
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url
    };
    this.context.startAbility(want).then(() => {
      result.success(null);
    }).catch((error: BusinessError) => {
      Log.e(TAG, `openUrl failed: ${error.code} ${error.message}`);
      result.error('OPEN_ERROR', error.message, null);
    });
  }

  private handleLog(call: MethodCall): void {
    const message: string = call.argument('message');
    if (typeof message !== 'string' || message.length === 0) {
      return;
    }
    const chunkSize = 800;
    const chunks: string[] = [];
    for (let i = 0; i < message.length; i += chunkSize) {
      const end = i + chunkSize > message.length ? message.length : i + chunkSize;
      chunks.push(message.substring(i, end));
    }
    for (let i = 0; i < chunks.length; i++) {
      hilog.info(0x0000, TAG, 'DartError[%{public}d/%{public}d]: %{public}s', i + 1, chunks.length, chunks[i]);
    }
  }

  private aliasQuery(id: string): asset.AssetMap {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.encoder.encodeInto(id));
    return query;
  }
}
