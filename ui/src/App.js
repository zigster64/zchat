import logo from './logo.svg';
import './App.css';

import { useEventSource } from 'react-use-websocket';
import { useState } from 'react';

function App() {
  const [lastChar, setLastChar] = useState(null);

  const hexButtons = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'];
  const cuniformButtons = ['𒁹', '𒀸', '𒀹', '𒀺', '𒁇', '𒀀', '𒀅', '𒂿'];
  const emojiButtons = ['😀', '🤣', '🫠', '🙃'];

  const { lastEvent, getEventSource, readyState } = useEventSource(
    'http://localhost:3000/events',
    {
      withCredentials: true,
      events: {
        message: (messageEvent) => {
          console.log('This has type "message": ', messageEvent);
        },
        update: (messageEvent) => {
          console.log('This has type "update": ', messageEvent);
        },
      },
    }
  );

  const Button = (data) => {
    const displayChar = data.char ? data.char : data.emoji ? data.emoji : data.cuniform;

    const handleClick = async () => {
      let payload = data;

      if (data.char) {
        if (!lastChar) {
          setLastChar(data.char)
          return;
        }
        // transform payload into a 2byte word
        const hexString = lastChar + data.char;
        const decimalValue = parseInt(hexString, 16);
        payload = {
          byte: hexString,
          char: String.fromCharCode(decimalValue)
        }
      }
      setLastChar(null)
      try {
        const response = await fetch('http://localhost:3000/chat', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ payload }),
        });

        if (!response.ok) {
          throw new Error('POST chat request failed');
        }
        const res_data = await response.json();
        console.log('Response data:', res_data);
      } catch (error) {
        console.error('Error:', error.message);
      }
    }

    return (
      <div className="grid-item" onClick={handleClick}>{displayChar}</div>
    )

  }

  return (
    <div className="App">
      <header className="App-header">
        <h1>Z-Chat</h1>
        <div className="grid-container">
          {hexButtons.map((char) => (
            <Button char={char} />
          ))}
          {emojiButtons.map((char) => (
            <Button emoji={char} />
          ))}
          {cuniformButtons.map((char) => (
            <Button cuniform={char} />
          ))}
        </div>
        <p className="hint">Communicate the easy and natural way using only Hexidecimal and Cuniform</p>
      </header>
    </div>
  );
}

export default App;
