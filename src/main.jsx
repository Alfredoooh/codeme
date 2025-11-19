import React from "react";
import { createRoot } from "react-dom/client";
import App from "./App.jsx"; // <-- importante: usar .jsx e o mesmo case
import "./index.css"; // se tiveres CSS

createRoot(document.getElementById("root")).render(<App />);