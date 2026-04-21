import '../models/pergunta.dart';

class BancoPerguntas {
  static final List<Pergunta> perguntas = [
    // CLÍNICA MÉDICA
    Pergunta(
      id: 'p1',
      enunciado: 'Paciente 25a dor torácica súbita, ECG normal?',
      resposta: 'Ansiedade/pânico. ECG normal exclui IAM agudo.',
      materia: 'Clínica Médica',
      tema: 'Cardiologia',
      subtema: 'Dor torácica',
    ),
    Pergunta(
  id: 'p7',
  enunciado: 'Paciente 25a dor torácica súbita ECG normal?',
  resposta: 'Ansiedade/pânico. ECG normal exclui IAM agudo.',
  materia: 'Clínica Médica',
  tema: 'Cardiologia',
  subtema: 'Dor torácica',
),
    Pergunta(
      id: 'p2',
      enunciado: 'HAS estágio 1 sem lesão órgão-alvo?',
      resposta: 'Estilo vida + monitorar. Rx IECA se persistir 3-6m.',
      materia: 'Clínica Médica',
      tema: 'Cardiologia',
      subtema: 'Hipertensão',
    ),
    Pergunta(
      id: 'p5',
      enunciado: 'Antibiótico 1ª linha pneumonia comunitária?',
      resposta: 'Amoxiclava ou azitromicina (macrolídeo).',
      materia: 'Clínica Médica',
      tema: 'Pneumonias',
      subtema: 'Comunitária',
    ),
    
    // CIRURGIA GERAL
    Pergunta(
      id: 'p3',
      enunciado: 'Dor FID + febre + náusea = ?',
      resposta: 'Apendicite aguda. McBurney+, ultrassom.',
      materia: 'Cirurgia Geral',
      tema: 'Abdome Agudo',
      subtema: 'Apendicite',
    ),
    Pergunta(
      id: 'p6',
      enunciado: 'Sinais colecistite aguda?',
      resposta: 'Dor QHI, sinal Murphy+, febre, leucocitose.',
      materia: 'Cirurgia Geral',
      tema: 'Vesícula Biliar',
      subtema: 'Colecistite',
    ),
    
    // PEDIATRIA
    Pergunta(
      id: 'p4',
      enunciado: 'Criança 2a febre + sibilos?',
      resposta: 'Bronquiolite VSR. Suporte + O2 se Sat <92%.',
      materia: 'Pediatria',
      tema: 'Vias Aéreas',
      subtema: 'Bronquiolite',
    ),
  ];
}
