# Configuração do webhook Mercado Pago

**Projeto:** `revalida-cards`  
**Function:** `mercadopagoWebhook` (HTTP, região `southamerica-east1`)

Este documento é a **fonte única** para URL e variáveis do IPN. O checkout usa a mesma URL em `notification_url`.

---

## URL do webhook (confirmar após deploy)

A URL **não é garantida automaticamente** pelo repositório. Após cada deploy, obtenha a URL **realmente publicada** e use **a mesma string** em todos os lugares.

### 1. Confirmar a URL publicada no Firebase

```bash
firebase functions:list --project revalida-cards
```

Localize a function `mercadopagoWebhook` e copie a URL HTTPS exibida (Trigger / URI).

### 2. Usar essa URL em três pontos

| Onde | O que colocar |
|------|----------------|
| Firebase param `MERCADOPAGO_WEBHOOK_URL` | URL copiada do passo 1 |
| Painel Mercado Pago → Webhooks / IPN | **Exatamente** a mesma URL |
| `notification_url` do checkout | Vem do param acima (automático) |

### URL de referência no projeto (Gen2)

Para o projeto `revalida-cards`, a URL **esperada** costuma ser:

```
https://southamerica-east1-revalida-cards.cloudfunctions.net/mercadopagoWebhook
```

Ela aparece em `functions/.env.revalida-cards` e na constante `OFFICIAL_MERCADOPAGO_WEBHOOK_URL` em `functions/src/mercadoPagoRuntimeConfig.ts` apenas como **referência e auditoria em log** — não substitui a confirmação com `firebase functions:list`.

Se a URL publicada for diferente da referência, **prevalece a URL publicada**: atualize o param Firebase, o painel MP e (se necessário) `functions/.env.revalida-cards` para ficarem iguais.

---

## Onde configurar

| O quê | Onde | Variável / secret |
|--------|------|-------------------|
| URL do webhook (IPN + checkout) | Firebase Functions **params** | `MERCADOPAGO_WEBHOOK_URL` |
| Assinatura `x-signature` | Firebase Functions **secrets** | `MERCADOPAGO_WEBHOOK_SECRET` |
| Token API Mercado Pago | Firebase Functions **secrets** | `MERCADOPAGO_ACCESS_TOKEN` |
| Pular assinatura (só emulador) | Firebase **params** ou `.env` local | `MERCADOPAGO_WEBHOOK_SKIP_SIGNATURE` |
| Checkout sem webhook (só dev) | Firebase **params** | `MERCADOPAGO_ALLOW_CHECKOUT_WITHOUT_WEBHOOK` |

### Comandos Firebase

Substitua `SUA_URL_PUBLICADA` pela URL obtida em `firebase functions:list`:

```bash
firebase functions:secrets:set MERCADOPAGO_ACCESS_TOKEN
firebase functions:secrets:set MERCADOPAGO_WEBHOOK_SECRET

firebase functions:params:set MERCADOPAGO_WEBHOOK_URL="SUA_URL_PUBLICADA"

firebase functions:params:set MERCADOPAGO_WEBHOOK_SKIP_SIGNATURE=false

firebase deploy --only functions:mercadopagoWebhook,functions:createMercadoPagoCheckout
```

Exemplo se a URL publicada for a de referência Gen2:

```bash
firebase functions:params:set MERCADOPAGO_WEBHOOK_URL="https://southamerica-east1-revalida-cards.cloudfunctions.net/mercadopagoWebhook"
```

### Painel Mercado Pago

1. [Mercado Pago Developers](https://www.mercadopago.com.br/developers) → sua aplicação  
2. **Webhooks / Notificações IPN**  
3. URL: **exatamente** a URL publicada confirmada no Firebase (mesma do param)  
4. Eventos: **pagamentos** (`payment` / created / updated)  
5. Copiar o **secret** do webhook para `MERCADOPAGO_WEBHOOK_SECRET` no Firebase (mesmo valor)

---

## Validação da assinatura (`x-signature`)

| Ambiente | Comportamento |
|----------|----------------|
| **Produção** (`revalida-cards`, não emulador) | Assinatura **sempre obrigatória**; `MERCADOPAGO_WEBHOOK_SKIP_SIGNATURE=true` é **ignorado** pelo código |
| **Emulador** (`FUNCTIONS_EMULATOR=true`) | Pode usar `MERCADOPAGO_WEBHOOK_SKIP_SIGNATURE=true` só em testes locais |
| **Produção — param Firebase** | Manter `MERCADOPAGO_WEBHOOK_SKIP_SIGNATURE=false` (não confiar em skip em prod) |

Implementação: `shouldSkipMercadoPagoWebhookSignature()` em `functions/src/mercadoPagoRuntimeConfig.ts`.

---

## `notification_url` no checkout

A callable `createMercadoPagoCheckout` (`functions/src/createCheckout.ts`) envia:

```text
notification_url = valor de MERCADOPAGO_WEBHOOK_URL
```

Se o param estiver vazio, o checkout **falha** em produção (exceto `MERCADOPAGO_ALLOW_CHECKOUT_WITHOUT_WEBHOOK=true` em dev).

---

## Logs de configuração

Em cada chamada ao webhook e no checkout, o sistema registra:

- `webhook.config_audit` — URL configurada vs referência do código, skip efetivo  
- `webhook.config_unsafe_skip_in_production` — tentativa de skip em produção  
- `webhook.config_url_mismatch_canonical` — param diferente da referência `OFFICIAL_MERCADOPAGO_WEBHOOK_URL`  

Consultar:

```bash
firebase functions:log --only mercadopagoWebhook --project revalida-cards
```

---

## Arquivos de referência local

| Arquivo | Uso |
|---------|-----|
| `functions/.env.revalida-cards` | Referência local; conferir com URL publicada após deploy |
| `functions/.env.revalida-cards.emulator.example` | Exemplo para emulador (`SKIP_SIGNATURE=true` só local) |

**Produção:** `MERCADOPAGO_WEBHOOK_SKIP_SIGNATURE=false` no Firebase. Não usar skip em produção.

---

## Checklist antes de aceitar pagamentos

- [ ] Deploy de `mercadopagoWebhook` e `createMercadoPagoCheckout`  
- [ ] URL confirmada: `firebase functions:list --project revalida-cards`  
- [ ] `MERCADOPAGO_WEBHOOK_URL` = URL **realmente publicada**  
- [ ] Painel Mercado Pago com a **mesma** URL  
- [ ] `MERCADOPAGO_WEBHOOK_SECRET` = secret do painel MP  
- [ ] `MERCADOPAGO_WEBHOOK_SKIP_SIGNATURE=false` no Firebase (produção)  
- [ ] Teste de pagamento → log `webhook.received` + ativação premium  
