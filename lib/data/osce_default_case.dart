import '../models/osce_models.dart';

/// Caso clínico padrão — pancreatite crônica (seed Firestore).
class OsceDefaultCase {
  OsceDefaultCase._();

  static const defaultCaseId = 'caso_pancreatite_cronica';

  static Map<String, dynamic> firestoreMap() => {
        'title': 'Dor abdominal e emagrecimento — UBS',
        'specialty': 'Clínica Médica',
        'scenario': '''
Nível de atenção: atenção primária à saúde.
Tipo de atendimento: ambulatorial.

A unidade apresenta:
• consultório médico;
• acesso a exames laboratoriais.''',
        'caseDescription': '''
Paciente de 48 anos procura a UBS com dor abdominal persistente e emagrecimento há 6 meses. Ele traz exame de imagem realizado previamente.''',
        'tasks': '''
• realizar anamnese;
• solicitar exame físico;
• avaliar exames;
• verbalizar hipótese diagnóstica;
• indicar tratamento;
• responder dúvidas do paciente.''',
        'actorScript': {
          'dados_pessoais':
              'Gláucio, 48 anos, pedreiro, casado, mora com esposa e dois filhos.',
          'motivo_consulta':
              '“Doutor(a), eu continuo com uma dor na boca do estômago que não passa e estou emagrecendo muito.”',
          'sintomas':
              'Início há 6 meses; piora progressiva; irradiação para dorso; piora após gordura; intensidade 7/10.',
          'habitos_alimentares':
              'Perda de 10 kg; poliúria; polidipsia; esteatorreia; dieta irregular.',
          'antecedentes_pessoais':
              'Etilismo importante (4-6 doses/dia há 20 anos); tabagismo 20 maços/ano; exame de imagem prévio com alteração pancreática.',
          'antecedentes_familiares':
              'Pai com diabetes mellitus; mãe hipertensa.',
          'duvidas':
              '“O que eu tenho?” / “Vou precisar operar?” / “Posso continuar bebendo?”',
          'respostas_permitidas':
              'Responder apenas com informações do script. Se perguntar fora do roteiro: “Informação não disponível no roteiro.”',
        },
        'physicalExamContent': '''
Abdome: dor em epigástrio e hipocôndrio esquerdo, sem defesa.
Pele: icterícia leve.
Peso: 68 kg (perda de 10 kg em 6 meses).''',
        'laboratoryContent': '''
Glicemia de jejum: 198 mg/dL
HbA1c: 9,2%
Amilase: discretamente elevada
Lipase: elevada
Triglicerídeos: 320 mg/dL''',
        'imagingContent': '''
TC abdome (prévia): atrofia pancreática, calcificações ductais, ducto de Wirsung dilatado.''',
        'hiddenDiagnosis': 'Pancreatite crônica com provável diabetes secundário',
        'isDefault': true,
      };

  static OsceCaseModel get model =>
      OsceCaseModel.fromMap(defaultCaseId, firestoreMap());
}
