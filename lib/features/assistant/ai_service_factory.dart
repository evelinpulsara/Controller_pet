import 'backend_pet_ai_service.dart';
import 'gemini_pet_safety_ai_service.dart';
import 'pet_safety_ai_service.dart';

class AiServiceFactory {
  const AiServiceFactory({this.backendUrl = '', this.geminiKey = '', this.geminiModel = ''});

  final String backendUrl;
  final String geminiKey;
  final String geminiModel;

  PetSafetyAiService create() {
    final fallback = MockPetSafetyAiService();
    if (backendUrl.isNotEmpty) {
      return BackendPetAiService(baseUrl: backendUrl, fallback: fallback);
    }
    if (geminiKey.isNotEmpty) {
      return GeminiPetSafetyAiService(
        apiKey: geminiKey,
        models: [if (geminiModel.isNotEmpty) geminiModel, ...GeminiPetSafetyAiService.defaultModels],
        fallback: fallback,
      );
    }
    return fallback;
  }
}
