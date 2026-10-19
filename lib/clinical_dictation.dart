import 'package:speech_to_text/speech_to_text.dart';
class ClinicalDictation {
  static final _speech=SpeechToText();
  static void Function(String)? _status;
  static void Function(String)? _error;
  static bool get listening => _speech.isListening;
  static Future<bool> start(void Function(String) words,void Function(String) status,void Function(String) error) async {
    _status=status; _error=error;
    final ok=await _speech.initialize(onStatus:(v)=>_status?.call(v),onError:(_)=>_error?.call('No se pudo completar el dictado. Puedes escribir o usar el micrófono del teclado.'));
    if(!ok) return false;
    final locales=await _speech.locales();
    final spanish=locales.where((l)=>l.localeId.toLowerCase().startsWith('es')).toList();
    if(spanish.isEmpty) return false;
    await _speech.listen(onResult:(r)=>words(r.recognizedWords),localeId:spanish.first.localeId,listenFor:const Duration(seconds:50),listenOptions:SpeechListenOptions(partialResults:true,cancelOnError:true,listenMode:ListenMode.dictation));
    return true;
  }
  static Future<void> stop() async { await _speech.stop(); }
  static void dispose() { _status=null; _error=null; _speech.cancel(); }
}
