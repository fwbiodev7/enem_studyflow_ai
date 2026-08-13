import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/study_block.dart';

class AiService {
  // ATENÇÃO: Substitua pela sua chave do Google AI Studio (não commite no GitHub!)
  static const String _apiKey = 'SUA_CHAVE_GEMINI_AQUI';
  
  Future<List<StudyBlock>> generateSchedule(String subjects, int hoursPerDay) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final prompt = '''
Você é um especialista em cronogramas de estudos para o ENEM.
Crie um plano diário de estudos para um aluno que tem dificuldade em: $subjects.
O aluno tem $hoursPerDay horas hoje (divida em blocos de no máximo 2h com intervalos não inclusos no json).
Retorne APENAS um JSON válido neste exato formato de array (sem blocos de código markdown como ```json):
[
  {
    "id": "1",
    "subject": "Matemática (Geometria)",
    "startHour": 14,
    "startMinute": 0,
    "endHour": 15,
    "endMinute": 30
  }
]
A soma das horas não pode passar de $hoursPerDay.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      String jsonText = response.text?.trim() ?? '[]';
      
      // Limpeza robusta caso a IA retorne formatação markdown
      if (jsonText.startsWith('```json')) jsonText = jsonText.substring(7);
      if (jsonText.startsWith('```')) jsonText = jsonText.substring(3);
      if (jsonText.endsWith('```')) jsonText = jsonText.substring(0, jsonText.length - 3);
      
      final List<dynamic> jsonList = jsonDecode(jsonText.trim());
      List<StudyBlock> blocks = [];
      final now = DateTime.now();
      
      for (var json in jsonList) {
        final start = DateTime(now.year, now.month, now.day, json['startHour'], json['startMinute']);
        final end = DateTime(now.year, now.month, now.day, json['endHour'], json['endMinute']);
        
        blocks.add(StudyBlock(
          id: json['id'].toString(),
          subject: json['subject'],
          startTime: start,
          endTime: end,
        ));
      }
      return blocks;
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        throw Exception('Sem conexão com a internet. Verifique sua rede e tente novamente.');
      } else if (e.toString().contains('429')) {
        throw Exception('Limite de requisições excedido (Rate Limit). Tente novamente mais tarde.');
      } else if (e.toString().contains('API key not valid')) {
        throw Exception('Chave de API inválida. Verifique sua configuração.');
      }
      throw Exception('Falha ao gerar cronograma. Verifique sua chave API ou tente novamente. Erro: $e');
    }
  }
}
