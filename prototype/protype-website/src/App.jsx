import { useState } from "react";
import RsyncPrototype from "./RsyncFileSync";
import RsyncPrototypeFile from "./RsyncProtoType";
import Tabs from "./Tab";
import "./App.css";
import "./tailwind.css";

function App() {
  const [count, setCount] = useState(0);
  const [showPrototype, setShowPrototype] = useState(true);
  const [prototypeIndex, setPrototypeIndex] = useState(0);

  return (
    <>
      <Tabs />
      <h1>Vite + React</h1>
      <button onClick={() => setShowPrototype(!showPrototype)}>
        {showPrototype ? "Hide" : "Show"} Rsync Prototype
      </button>
      {!showPrototype && (
        <div className="card">
          <button onClick={() => setCount((count) => count + 1)}>
            count is {count}
          </button>
          <p>
            Edit <code>src/App.jsx</code> and save to test HMR
          </p>
        </div>
      )}
      {showPrototype && <RsyncPrototype />}
    </>
  );
}

export default App;
