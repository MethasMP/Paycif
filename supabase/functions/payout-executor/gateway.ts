// ============================================================================
// GATEWAY.TS - Pluggable Gateway Architecture
// ============================================================================
// This module provides a clean abstraction for payment gateway integrations.
// Currently implements a MockGateway for development/testing.
// Future: SCBGateway, TwoC2PGateway
// ============================================================================

import { GatewayPayoutRequest, GatewayPayoutResponse } from './types.ts';

/**
 * Gateway Configuration
 * In production, these would come from environment variables
 */
const GATEWAY_CONFIG = {
  // Mock endpoint - use webhook.site or beeceptor for testing
  // Example: https://webhook.site/your-unique-id
  MOCK_ENDPOINT: Deno.env.get('MOCK_GATEWAY_URL') || 'https://webhook.site/test-paysif',

  // Simulated delay in milliseconds (realistic for PromptPay: 2-5 seconds)
  SIMULATED_DELAY_MS: 500,

  // Request timeout in milliseconds
  TIMEOUT_MS: 10000,
};

/**
 * Abstract Gateway Interface
 * All gateway implementations must follow this contract
 */
export interface IPayoutGateway {
  name: string;
  execute(request: GatewayPayoutRequest): Promise<GatewayPayoutResponse>;
}

/**
 * MockGateway - Development/Testing Implementation
 *
 * Features:
 * 1. Simulated delay to mimic real PromptPay processing time
 * 2. Optional HTTP call to webhook.site/beeceptor for payload inspection
 * 3. Configurable success/failure simulation
 */
export class MockGateway implements IPayoutGateway {
  name = 'MockGateway';

  private endpoint: string;
  private delayMs: number;
  private timeoutMs: number;

  constructor(
    endpoint: string = GATEWAY_CONFIG.MOCK_ENDPOINT,
    delayMs: number = GATEWAY_CONFIG.SIMULATED_DELAY_MS,
    timeoutMs: number = GATEWAY_CONFIG.TIMEOUT_MS,
  ) {
    this.endpoint = endpoint;
    this.delayMs = delayMs;
    this.timeoutMs = timeoutMs;
  }

  async execute(request: GatewayPayoutRequest): Promise<GatewayPayoutResponse> {
    console.log(`[${this.name}] Executing payout: ${request.reference_id}`);
    console.log(`[${this.name}] Amount: ${request.amount_satang} satang`);
    console.log(`[${this.name}] Target: ${request.target_type}:${request.target_value}`);

    try {
      // STEP 1: Simulate realistic processing delay
      console.log(`[${this.name}] Simulating ${this.delayMs}ms delay...`);
      await this.simulateDelay(this.delayMs);

      // STEP 2: Make real HTTP call to mock endpoint (for payload inspection)
      const httpResult = await this.makeHttpCall(request);

      // STEP 3: Return success response
      const gatewayRef = `MOCK-${Date.now()}-${Math.random().toString(36).substring(7)}`;

      return {
        success: true,
        gateway_ref: gatewayRef,
        raw_response: httpResult,
      };
    } catch (error) {
      console.error(`[${this.name}] Error:`, error);

      return {
        success: false,
        error_code: 'GATEWAY_ERROR',
        error_message: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  /**
   * Simulate delay to mimic real gateway processing time
   */
  private simulateDelay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Make actual HTTP call to mock endpoint
   * This allows you to inspect the payload in webhook.site/beeceptor
   */
  private async makeHttpCall(request: GatewayPayoutRequest): Promise<unknown> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeoutMs);

    try {
      const response = await fetch(this.endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Paysif-Source': 'payout-executor',
          'X-Paysif-Env': 'development',
        },
        body: JSON.stringify({
          ...request,
          sent_at: new Date().toISOString(),
        }),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      // For webhook.site, we don't expect meaningful response
      // Just log the status for debugging
      console.log(`[${this.name}] HTTP Status: ${response.status}`);

      return {
        status: response.status,
        ok: response.ok,
      };
    } catch (error) {
      clearTimeout(timeoutId);

      if (error instanceof Error && error.name === 'AbortError') {
        console.warn(`[${this.name}] Request timed out after ${this.timeoutMs}ms`);
        // For mock, we still return success even on timeout
        // In production, this would be a failure
        return { timeout: true };
      }

      // For mock purposes, HTTP failures don't fail the payout
      // This allows testing without a real mock server
      console.warn(`[${this.name}] HTTP call failed (non-fatal):`, error);
      return { error: 'HTTP call failed', details: String(error) };
    }
  }
}

/**
 * Gateway Factory
 * Returns the appropriate gateway based on environment
 */
export function createGateway(): IPayoutGateway {
  const gatewayType = Deno.env.get('PAYOUT_GATEWAY') || 'MOCK';

  switch (gatewayType.toUpperCase()) {
    case 'MOCK':
      return new MockGateway();

    // Future implementations:
    // case 'SCB':
    //   return new SCBGateway();
    // case '2C2P':
    //   return new TwoC2PGateway();

    default:
      console.warn(`Unknown gateway type: ${gatewayType}, falling back to MockGateway`);
      return new MockGateway();
  }
}
