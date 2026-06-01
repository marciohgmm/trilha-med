import { MercadoPagoConfig, Payment } from "mercadopago";
import { logSubscriptionError } from "./subscriptionLogger";

export type MpPaymentRecord = {
  id?: string | number;
  status?: string;
  external_reference?: string;
  transaction_amount?: number;
  metadata?: Record<string, unknown>;
  date_created?: string;
};

/** Consulta pagamento na API Mercado Pago (fonte de verdade). */
export async function fetchMercadoPagoPayment(
  accessToken: string,
  mpPaymentId: string
): Promise<MpPaymentRecord | null> {
  try {
    const client = new MercadoPagoConfig({ accessToken });
    const paymentClient = new Payment(client);
    const mpPayment = await paymentClient.get({ id: mpPaymentId });
    return (mpPayment ?? null) as MpPaymentRecord | null;
  } catch (err) {
    logSubscriptionError("mp.fetch_payment_failed", err, { mpPaymentId });
    return null;
  }
}

/** Busca pagamentos MP pelo external_reference (= id do doc platform_payments). */
export async function searchMercadoPagoPaymentsByExternalReference(
  accessToken: string,
  externalReference: string
): Promise<MpPaymentRecord[]> {
  const url = new URL("https://api.mercadopago.com/v1/payments/search");
  url.searchParams.set("external_reference", externalReference);
  url.searchParams.set("sort", "date_created");
  url.searchParams.set("criteria", "desc");

  try {
    const res = await fetch(url.toString(), {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!res.ok) {
      logSubscriptionError(
        "mp.search_failed",
        new Error(`HTTP ${res.status}`),
        { externalReference }
      );
      return [];
    }
    const body = (await res.json()) as {
      results?: MpPaymentRecord[];
    };
    return body.results ?? [];
  } catch (err) {
    logSubscriptionError("mp.search_error", err, { externalReference });
    return [];
  }
}

export function isMercadoPagoPaymentId(value: string): boolean {
  return /^\d+$/.test(value.trim());
}
