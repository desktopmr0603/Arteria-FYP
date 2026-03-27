import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'OPENAI_API_KEY')
  static const String openaiApiKey = _Env.openaiApiKey;

  @EnviedField(varName: 'RUNPOD_API_KEY')
  static const String runpodApiKey = _Env.runpodApiKey;

  @EnviedField(varName: 'QWEN_SERVER_URL', defaultValue: 'http://localhost:8000')
  static const String qwenServerUrl = _Env.qwenServerUrl;
}
