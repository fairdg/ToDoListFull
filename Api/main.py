from fastapi import FastAPI, Depends
from typing import Annotated
from pydantic import BaseModel, Field
import uvicorn
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import declarative_base, Mapped, mapped_column
from sqlalchemy import select
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
WEB_DIR = BASE_DIR.parent / "Web"

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=str(WEB_DIR)), name="web")

engine = create_async_engine("sqlite+aiosqlite:///./ToDoList.db")
new_session = async_sessionmaker(engine, expire_on_commit=False)

async def get_session():
    async with new_session() as session:
        yield session
sessiondep = Annotated[AsyncSession, Depends(get_session)]

Base = declarative_base()

class TaskModel(Base):
    __tablename__ = "tasks"
    id: Mapped[int] = mapped_column(primary_key=True)
    text: Mapped[str] = mapped_column()
    completed: Mapped[bool] = mapped_column(default=False)

class TaskAddSchema(BaseModel):
    text: str = Field(min_length=1, max_length=500)
    completed: bool = False

def serialize_task(task: "TaskModel") -> dict:
    return {"id": task.id, "text": task.text, "completed": task.completed}


@app.get("/api/tasks")
async def get_tasks(session: sessiondep):
    result = await session.execute(select(TaskModel))
    tasks = result.scalars().all()
    return [serialize_task(task) for task in tasks]

@app.post("/api/tasks")
async def create_task(task: TaskAddSchema, session: sessiondep):
    new_task = TaskModel(text=task.text, completed=task.completed)
    session.add(new_task)
    await session.commit()
    await session.refresh(new_task)
    return {"message": "Задача добавлена", "task": serialize_task(new_task)}

@app.put("/api/tasks/{id}")
async def update_task(id: int, updated_task: TaskAddSchema, session: sessiondep):
    task = await session.get(TaskModel, id)
    if not task:
        return {"message": "Задача не найдена"}
    task.text = updated_task.text
    task.completed = updated_task.completed
    await session.commit()
    return {"message": "Задача обновлена", "task": serialize_task(task)}

@app.patch("/api/tasks/{id}/toggle")
async def switch_completed(id: int, session: sessiondep):
    task = await session.get(TaskModel, id)
    if not task:
        return {"message": "Задача не найдена"}
    task.completed = not task.completed
    await session.commit()
    return {"message": "Статус задачи изменен", "task": serialize_task(task)}

@app.delete("/api/tasks/{id}")
async def delete_task(id: int, session: sessiondep):
    task = await session.get(TaskModel, id)
    if not task:
        return {"message": "Задача не найдена"}
    await session.delete(task)
    await session.commit()
    return {"message": "Задача удалена"}


@app.get("/", response_class=FileResponse)
async def read_index():
    return FileResponse(WEB_DIR / "index.html")

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

