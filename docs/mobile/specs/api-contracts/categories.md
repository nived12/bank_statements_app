# API Contract: Categories

> Reviewed: 2026-04-16 (Phase 2 — destroy envelope fixed)

Base path: `/api/v1/categories`
Auth: JWT Bearer required on all endpoints

---

## GET /api/v1/categories

Returns all categories for the authenticated user, hierarchical (top-level only, with subcategories nested via `children`).

### Response 200

```json
{
  "data": {
    "categories": [
      {
        "id": 12,
        "name": "Food",
        "icon": "utensils",
        "parent_id": null,
        "transaction_count": 44,
        "children": [
          {
            "id": 15,
            "name": "Groceries",
            "icon": "shopping-cart",
            "parent_id": 12,
            "transaction_count": 22,
            "children": []
          }
        ]
      }
    ]
  },
  "meta": {
    "pagination": { ... }
  }
}
```

---

## GET /api/v1/categories/:id

Returns a single category with its children.

### Response 200

```json
{
  "data": { ... category object ... }
}
```

### Response 404

```json
{
  "error": {
    "message": "Category not found",
    "code": "CATEGORY_NOT_FOUND",
    "details": []
  }
}
```

---

## POST /api/v1/categories

Create a new category.

### Request Body

```json
{
  "category": {
    "name": "Entertainment",
    "icon": "tv",
    "parent_id": null
  }
}
```

### Response 201

```json
{
  "data": { ... category object ... },
  "message": "Category created successfully"
}
```

---

## PATCH /api/v1/categories/:id

Update a category.

### Response 200

```json
{
  "data": { ... updated category object ... },
  "message": "Category updated successfully"
}
```

---

## DELETE /api/v1/categories/:id

Delete a category. Transactions in this category are uncategorized (category_id set to null). Cannot delete if subcategories exist.

### Response 200

```json
{
  "data": {
    "message": "Category deleted successfully"
  }
}
```

### Response 422 (has subcategories)

```json
{
  "error": {
    "message": "Cannot delete category with subcategories",
    "code": "DELETE_NOT_ALLOWED",
    "details": []
  }
}
```
