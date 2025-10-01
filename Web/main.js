const API_BASE = '/api/tasks';

const form = document.querySelector('#ToDo');
const taskInput = document.querySelector('#taskinput');
const tasksList = document.querySelector('#taskslist');
let tasks = [];

document.addEventListener('DOMContentLoaded', () => {
  loadTasks();
});

form.addEventListener('submit', addTask);
tasksList.addEventListener('click', handleTaskListClick);

async function loadTasks() {
  try {
    const response = await fetch(API_BASE);
    if (!response.ok) {
      throw new Error('Не удалось получить задачи с сервера');
    }
    const data = await response.json();
    tasks = Array.isArray(data) ? data : [];
  } catch (error) {
    console.error(error);
    tasks = [];
  }
  renderTasks();
}

function renderTasks() {
  tasksList.innerHTML = '';

  if (tasks.length === 0) {
    tasksList.innerHTML = '<li class="empty-list">Нет задач</li>';
    return;
  }

  tasks.forEach(task => {
    const cssClass = task.completed ? 'task-text done' : 'task-text';
    const taskHTML = `
      <li id="${task.id}" class="listitem">
        <span class="${cssClass}">${escapeHtml(task.text)}</span>
        <button class="done-btn">${task.completed ? 'Сделать невыполненной' : 'Отметить выполненной'}</button>
        <button class="delete">Удалить</button>
        <button class="edit">Редактировать</button>
      </li>
    `;
    tasksList.insertAdjacentHTML('beforeend', taskHTML);
  });
}

function handleTaskListClick(event) {
  if (event.target.classList.contains('delete')) {
    deleteTask(event);
  } else if (event.target.classList.contains('done-btn')) {
    toggleTask(event);
  } else if (event.target.classList.contains('edit')) {
    startEdit(event);
  }
}

async function addTask(event) {
  event.preventDefault();
  const taskText = taskInput.value.trim();

  if (!taskText) {
    return;
  }

  try {
    const response = await fetch(API_BASE, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text: taskText, completed: false }),
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.message || 'Не удалось добавить задачу');
    }

    if (data.task) {
      tasks.push(data.task);
      renderTasks();
    }

    form.reset();
    taskInput.focus();
  } catch (error) {
    console.error(error);
    alert('Не получилось добавить задачу. Попробуйте позже.');
  }
}

async function deleteTask(event) {
  const listItem = event.target.closest('.listitem');
  const taskId = Number(listItem.id);

  try {
    const response = await fetch(`${API_BASE}/${taskId}`, {
      method: 'DELETE',
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.message || 'Не удалось удалить задачу');
    }

    tasks = tasks.filter(task => task.id !== taskId);
    renderTasks();
  } catch (error) {
    console.error(error);
    alert('Не получилось удалить задачу. Попробуйте позже.');
  }
}

async function toggleTask(event) {
  const listItem = event.target.closest('.listitem');
  const taskId = Number(listItem.id);

  try {
    const response = await fetch(`${API_BASE}/${taskId}/toggle`, {
      method: 'PATCH',
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.message || 'Не удалось изменить статус задачи');
    }

    if (data.task) {
      tasks = tasks.map(task => (task.id === taskId ? data.task : task));
      renderTasks();
    }
  } catch (error) {
    console.error(error);
    alert('Не получилось изменить статус. Попробуйте позже.');
  }
}

function startEdit(event) {
  const listItem = event.target.closest('.listitem');
  const taskId = Number(listItem.id);
  const task = tasks.find(item => item.id === taskId);

  if (!task) {
    return;
  }

  const textElement = listItem.querySelector('.task-text');
  const editInput = document.createElement('input');
  editInput.type = 'text';
  editInput.value = task.text;
  editInput.className = 'edit-input';

  textElement.replaceWith(editInput);
  editInput.focus();

  const finalizeEdit = async commit => {
    editInput.removeEventListener('blur', handleBlur);
    editInput.removeEventListener('keydown', handleKeyDown);

    if (!commit) {
      renderTasks();
      return;
    }

    const newText = editInput.value.trim();
    await finishEdit(taskId, newText, task);
  };

  const handleBlur = () => finalizeEdit(true);
  const handleKeyDown = eventKey => {
    if (eventKey.key === 'Enter') {
      eventKey.preventDefault();
      finalizeEdit(true);
    } else if (eventKey.key === 'Escape') {
      eventKey.preventDefault();
      finalizeEdit(false);
    }
  };

  editInput.addEventListener('blur', handleBlur);
  editInput.addEventListener('keydown', handleKeyDown);
}

async function finishEdit(taskId, newText, task) {
  
  if (!newText || newText === task.text) {
    renderTasks();
    return;
  }

  try {
    const response = await fetch(`${API_BASE}/${taskId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text: newText, completed: task.completed }),
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.message || 'Не удалось обновить задачу');
    }

    if (data.task) {
      tasks = tasks.map(item => (item.id === taskId ? data.task : item));
      renderTasks();
    }
  } catch (error) {
    console.error(error);
    alert('Не получилось обновить задачу. Попробуйте позже.');
    renderTasks();
  }
}

function escapeHtml(text) {
  const map = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;',
  };

  return text.replace(/[&<>"']/g, char => map[char]);
}
