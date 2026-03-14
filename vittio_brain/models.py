from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from enum import Enum
from decimal import Decimal

class TransactionType(str, Enum):
    income = "income"
    fixed_expense = "fixed_expense"
    variable_expense = "variable_expense"
    transfer_out = "transfer_out"
    transfer_in = "transfer_in"

class Transaction(BaseModel):
    date: str = Field(description="ISO 8601 date string YYYY-MM-DD")
    description: str = Field(min_length=4)
    amount: Decimal
    transaction_type: TransactionType
    merchant: Optional[str] = None
    category_id: Optional[int] = None
    audit_note: Optional[str] = Field(
        default=None,
        description="Only required when confidence < 0.8; explain uncertainty/reasoning.",
    )
    confidence: float = Field(ge=0, le=1)

    @field_validator('amount')
    @classmethod
    def amount_must_not_be_zero(cls, v: Decimal) -> Decimal:
        if v == 0:
            raise ValueError('Amount cannot be zero')
        return v

class AuditResponse(BaseModel):
    transactions: List[Transaction]
    opening_balance: Optional[Decimal] = None
    closing_balance: Optional[Decimal] = None
