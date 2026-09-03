import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { resourceManager } from '@kit.LocalizationKit';
import { util } from '@kit.ArkTS';
import { Hypium } from '@ohos/hypium';
import testsuite from '../test/List.test';

let abilityDelegator: abilityDelegatorRegistry.AbilityDelegator;
let abilityDelegatorArguments: abilityDelegatorRegistry.AbilityDelegatorArgs;
let jsonPath: string = 'mock/mock-config.json';
let domain: number = 0x0000;
let tag: string = 'testTag';

class TestRunnerImpl implements TestRunner {
  constructor() {
  }

  onPrepare() {
    hilog.info(domain, tag, '%{public}s', 'TestRunner OnPrepare');
  }

  async onRun() {
    hilog.info(domain, tag, '%{public}s', 'TestRunner onRun run');
    abilityDelegatorArguments = abilityDelegatorRegistry.getArguments();
    abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();
    let moduleName = abilityDelegatorArguments.parameters['-m'];
    let context = abilityDelegator.getAppContext().getApplicationContext().createModuleContext(moduleName);
    let mResourceManager = context.resourceManager;
    await checkMock(abilityDelegator, mResourceManager);
    hilog.info(domain, tag, '%{public}s', 'start run testcase!!!');
    Hypium.hypiumTest(abilityDelegator, abilityDelegatorArguments, testsuite);
    hilog.info(domain, tag, '%{public}s', 'TestRunner onRun end');
  }
}

export default TestRunnerImpl;

async function checkMock(abilityDelegator: abilityDelegatorRegistry.AbilityDelegator, resourceManager: resourceManager.ResourceManager) {
  let rawFile: Uint8Array;
  try {
    rawFile = resourceManager.getRawFileContentSync(jsonPath);
    hilog.info(domain, tag, 'MockList file exists');
    let mockStr: string = util.TextDecoder.create('utf-8', { ignoreBOM: true }).decodeWithStream(rawFile);
    let mockMap: Record<string, string> = getMockList(mockStr);
    try {
      abilityDelegator.setMockList(mockMap);
    } catch (error) {
      let code = (error as BusinessError).code;
      let message = (error as BusinessError).message;
      hilog.error(domain, tag, `abilityDelegator.setMockList failed, error code: ${code}, message: ${message}.`);
    }
  } catch (error) {
    let code = (error as BusinessError).code;
    let message = (error as BusinessError).message;
    hilog.error(domain, tag, `ResourceManager:callback getRawFileContent failed, error code: ${code}, message: ${message}.`);
  }
}

function getMockList(jsonStr: string): Record<string, string> {
  let jsonObj: Record<string, Object> = JSON.parse(jsonStr);
  let map: Map<string, Object> = new Map<string, Object>(Object.entries(jsonObj));
  let mockList: Record<string, string> = {};
  map.forEach((value: Object, key: string) => {
    let realValue: string = (value as Record<string, string>)['source'].toString();
    mockList[key] = realValue;
  });
  return mockList;
}
