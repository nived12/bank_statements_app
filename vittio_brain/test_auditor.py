import asyncio
from auditor_agent import run_audit
import json

async def main():
    # A messy string simulating a real bank statement snippet
    raw_text = """
    01/03/2026  OXXO GAS MTY          -$500.00
    02/03/2026  SPEI TRANSFER BINANCE -$2000.00
    03/03/2026  DEPOSITO NOMINA       +$15000.00
    """
    
    print("🚀 Starting Audit...")
    try:
        data = await run_audit(raw_text)
        
        # This is where the magic happens: data is a Python Object, not text.
        for tx in data.transactions:
            print(f"---")
            print(f"Date: {tx.date}")
            print(f"Desc: {tx.description}")
            print(f"Amount: {tx.amount} ({tx.transaction_type})")
            print(f"Confidence: {tx.confidence}")
            if tx.audit_note:
                print(f"🧠 AI Note: {tx.audit_note}")
                
    except Exception as e:
        print(f"❌ Audit Failed: {e}")

if __name__ == "__main__":
    asyncio.run(main())
