from fastapi import APIRouter

from app.api.v1.auth.router import router as auth_router
from app.api.v1.collection.router import router as collection_router
from app.api.v1.custom_fields.router import router as custom_fields_router
from app.api.v1.search.router import router as search_router
from app.api.v1.users.router import router as users_router

api_v1_router = APIRouter(prefix="/api/v1")
api_v1_router.include_router(auth_router, prefix="/auth", tags=["auth"])
api_v1_router.include_router(collection_router, prefix="/collection", tags=["collection"])
api_v1_router.include_router(custom_fields_router, prefix="/custom-fields", tags=["custom-fields"])
api_v1_router.include_router(search_router, prefix="/search", tags=["search"])
api_v1_router.include_router(users_router, prefix="/users", tags=["users"])
