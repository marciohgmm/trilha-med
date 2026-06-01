# Ferramentas Médicas — Fase 1 (Pré-relatório)

**Data:** 2026-05-19  
**Escopo:** Auditoria somente leitura.

---

## MedicalToolsPage

- **Arquivo:** `lib/screens/medical_tools/medical_tools_page.dart`
- **Entrada:** Home → botão "Ferramentas Médicas"
- **Estado atual:** lista estática com SnackBar "em desenvolvimento" em todos os itens
- **Tema:** `#1E3A8A` (primário), `#2563EB` (accent), fundo `#F8FAFC`, cards brancos com borda `#E2E8F0`

## Navegação

| Origem | Destino |
|--------|---------|
| `HomePage._abrirFerramentasMedicas` | `MedicalToolsPage` |
| `FeatureGate` | `FeatureModules.ferramentasMedicas` |

Sem rotas nomeadas; `MaterialPageRoute` push.

## Componentes reutilizáveis (existentes)

- Cards `_ToolCard` / `_CategorySection` na própria página
- Padrão visual alinhado à Home (AppBar azul, botões arredondados 16–18px)
- `shared_preferences` já usado em `StudyTimerService`, `SimuladoSessionStore`

## Fase 1 — escopo de implementação

| Ferramenta | Página | Persistência |
|------------|--------|--------------|
| IMC Adulto | `AdultBmiCalculatorPage` | Histórico local |
| Dose por peso | `WeightDoseCalculatorPage` | Histórico local |
| Cockcroft-Gault | `CockcroftGaultCalculatorPage` | Histórico local |

Demais itens permanecem na lista sem navegação funcional (sem texto "Em desenvolvimento" nos três entregues).

## Restrições

- Sem Firestore / Firebase
- Offline-first
- Sem impacto em Premium ou monetização
