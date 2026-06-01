# Ferramentas Médicas — Fase 1 (Relatório de Implementação)

**Data:** 2026-05-19  
**Escopo:** 3 calculadoras funcionais + histórico local + testes unitários.

---

## Resumo

Implementadas as três primeiras Ferramentas Médicas com cálculo completo, interface mobile-friendly e histórico offline (últimos 20 cálculos). Nenhuma integração com Firestore ou monetização.

| Ferramenta | Página | Status |
|------------|--------|--------|
| IMC Adulto | `AdultBmiCalculatorPage` | ✅ Funcional |
| Dose por peso | `WeightDoseCalculatorPage` | ✅ Funcional |
| Cockcroft-Gault | `CockcroftGaultCalculatorPage` | ✅ Funcional |

---

## Fórmulas utilizadas

### IMC Adulto (OMS)

\[
IMC = \frac{peso\ (kg)}{altura\ (m)^2}
\]

Altura informada em cm e convertida para metros (`altura_cm / 100`).

**Classificação:**

| IMC | Classificação |
|-----|---------------|
| &lt; 18,5 | Baixo peso |
| 18,5 – 24,9 | Normal |
| 25 – 29,9 | Sobrepeso |
| 30 – 34,9 | Obesidade I |
| 35 – 39,9 | Obesidade II |
| ≥ 40 | Obesidade III |

**Implementação:** `lib/domain/medical_tools/adult_bmi.dart`

---

### Dose por peso

\[
Dose\ total\ (mg) = peso\ (kg) \times dose\ prescrita\ (mg/kg)
\]

Exemplo: 20 kg × 10 mg/kg = **200 mg**

**Implementação:** `lib/domain/medical_tools/weight_dose.dart`

---

### Cockcroft-Gault (creatinina em mg/dL)

**Masculino:**

\[
ClCr = \frac{(140 - idade) \times peso}{72 \times creatinina}
\]

**Feminino:** resultado × 0,85

**Interpretação clínica (estimativa):**

| ClCr (mL/min) | Interpretação |
|---------------|---------------|
| ≥ 90 | Normal ou levemente reduzida |
| 60 – 89 | Redução leve |
| 30 – 59 | Redução moderada |
| 15 – 29 | Redução grave |
| &lt; 15 | Falência renal |

**Implementação:** `lib/domain/medical_tools/cockcroft_gault.dart`

---

## Histórico local

- **Store:** `MedicalToolsHistoryStore` (`lib/services/medical_tools/medical_tools_history_store.dart`)
- **Persistência:** `SharedPreferences`, chave `medical_tools_history_v1`
- **Limite:** 20 entradas globais (mais recentes primeiro)
- **Modelo:** `MedicalToolHistoryEntry` com `toolId`, `title`, `summary`, `calculatedAt`
- **Exibição:** até 5 entradas recentes por calculadora na própria tela

Funciona **100% offline**, sem leitura/escrita Firebase.

---

## Cobertura de testes

**Diretório:** `test/medical_tools/`

| Arquivo | Casos |
|---------|-------|
| `adult_bmi_test.dart` | IMC, classificação OMS, limites, validação |
| `weight_dose_test.dart` | Exemplo 20×10=200, decimais, validação |
| `cockcroft_gault_test.dart` | M/F, fator 0,85, faixas clínicas, validação |
| `medical_tools_history_store_test.dart` | append, filtro por tool, limite 20, clear |

**Total:** 21 testes unitários (domínio + histórico).

Comando:

```bash
flutter test test/medical_tools/
```

---

## Impacto em custo Firebase

| Recurso | Uso |
|---------|-----|
| Firestore | ❌ Nenhum |
| Cloud Functions | ❌ Nenhum |
| Storage | ❌ Nenhum |
| Analytics | ❌ Não adicionado |

**Custo incremental:** **R$ 0** — apenas armazenamento local no dispositivo.

---

## Novas dependências

**Nenhuma.** Reutilizado `shared_preferences` já presente no `pubspec.yaml`.

---

## Arquivos criados / alterados

### Domínio

- `lib/domain/medical_tools/adult_bmi.dart`
- `lib/domain/medical_tools/weight_dose.dart`
- `lib/domain/medical_tools/cockcroft_gault.dart`

### Modelos e serviços

- `lib/models/medical_tool_history_entry.dart`
- `lib/services/medical_tools/medical_tools_history_store.dart`

### Telas

- `lib/screens/medical_tools/adult_bmi_calculator_page.dart`
- `lib/screens/medical_tools/weight_dose_calculator_page.dart`
- `lib/screens/medical_tools/cockcroft_gault_calculator_page.dart`
- `lib/screens/medical_tools/medical_tools_page.dart` *(atualizada — navegação às 3 ferramentas)*

### Widgets compartilhados

- `lib/widgets/medical_tools/medical_tools_theme.dart`
- `lib/widgets/medical_tools/medical_numeric_field.dart`
- `lib/widgets/medical_tools/medical_calculator_widgets.dart`

### Testes

- `test/medical_tools/adult_bmi_test.dart`
- `test/medical_tools/weight_dose_test.dart`
- `test/medical_tools/cockcroft_gault_test.dart`
- `test/medical_tools/medical_tools_history_store_test.dart`

### Documentação

- `docs/MEDICAL_TOOLS_PHASE1_PRE_REPORT.md`
- `docs/MEDICAL_TOOLS_PHASE1_IMPLEMENTATION_REPORT.md`

---

## Navegação

```
Home → Ferramentas Médicas → MedicalToolsPage
  ├── IMC Adulto → AdultBmiCalculatorPage
  ├── Cálculo de Dose por Peso → WeightDoseCalculatorPage
  └── Clearance (Cockcroft-Gault) → CockcroftGaultCalculatorPage
```

Demais calculadoras e bulários exibem **"Em breve"** com SnackBar — sem placeholder funcional nas três entregues.

---

## Restrições respeitadas

- ✅ Sem Firestore
- ✅ Offline-first
- ✅ Sem alteração em Premium / monetização
- ✅ Calculadoras totalmente funcionais (sem "Em desenvolvimento" nas 3 entregues)
