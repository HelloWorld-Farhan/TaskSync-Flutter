# 🛒 Cartly — Modern E-Commerce Platform

<p align="center">
  <strong>A modern, responsive and scalable e-commerce platform built for a smooth online shopping experience.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/React-2026-61DAFB?style=for-the-badge&logo=react&logoColor=black"/>
  <img src="https://img.shields.io/badge/Vite-7.x-646CFF?style=for-the-badge&logo=vite&logoColor=white"/>
  <img src="https://img.shields.io/badge/JavaScript-ES6+-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black"/>
  <img src="https://img.shields.io/badge/Node.js-Backend-339933?style=for-the-badge&logo=node.js&logoColor=white"/>
  <img src="https://img.shields.io/badge/Prisma-ORM-2D3748?style=for-the-badge&logo=prisma&logoColor=white"/>
  <img src="https://img.shields.io/badge/MongoDB-Database-47A248?style=for-the-badge&logo=mongodb&logoColor=white"/>
  <img src="https://img.shields.io/badge/TypeScript-Supported-3178C6?style=for-the-badge&logo=typescript&logoColor=white"/>
</p>

---

## 📖 About Cartly

**Cartly** is a modern full-stack e-commerce platform designed to provide users with a clean, responsive and intuitive online shopping experience.

The platform combines a fast React-based frontend with a scalable backend architecture, database management and API-driven services.

Cartly is designed around a simple goal:

> **Make online shopping fast, simple and enjoyable.**

The project includes product browsing, product details, shopping cart functionality, user interactions and a structured backend architecture for managing application data.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🛍️ **Product Browsing** | Browse and explore products through a clean and responsive interface. |
| 🔎 **Product Discovery** | Search and discover products easily. |
| 📦 **Product Details** | View detailed information about individual products. |
| 🛒 **Shopping Cart** | Add, remove and manage products in the shopping cart. |
| 📱 **Responsive Design** | Optimized for desktop, tablet and mobile devices. |
| ⚡ **Fast Performance** | Built with Vite for a fast development and production experience. |
| 🔗 **API Integration** | Communicates with the backend through REST APIs. |
| 🔐 **Authentication Ready** | Architecture prepared for secure user authentication and authorization. |
| 💾 **Database Integration** | Backend data is managed using Prisma and MongoDB. |
| 🧩 **Modular Architecture** | Components and features are organized for maintainability and scalability. |
| 🎨 **Modern UI** | Clean and modern interface designed for an e-commerce experience. |

---

# 🏗️ Project Architecture

Cartly is structured as a full-stack application:

```text
                    ┌──────────────────────┐
                    │       Cartly UI      │
                    │    React + Vite      │
                    └──────────┬───────────┘
                               │
                               │ REST API
                               ▼
                    ┌──────────────────────┐
                    │    Cartly Backend    │
                    │ Node.js / API Layer  │
                    └──────────┬───────────┘
                               │
                               │ Prisma ORM
                               ▼
                    ┌──────────────────────┐
                    │      MongoDB         │
                    │      Database        │
                    └──────────────────────┘
