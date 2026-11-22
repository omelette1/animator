// The code editor (CodeMirror 6).

let cmView = null;
let cmModulePromise = null;
let cmObserver = null;
let cmMountVersion = 0;

function defineGleam(StreamLanguage) {
  const keywords = new Set([
    "fn", "case", "let", "const", "import", "use", "type", "pub", "as", "if",
    "todo", "panic", "assert",
  ]);

  return StreamLanguage.define({
    token(stream) {
      if (stream.eatSpace()) return null;
      if (stream.match(/^\/\/.*/)) return "comment";
      if (stream.match(/^"(?:[^"\\]|\\.)*"?/)) return "string";

      if (
        stream.match(/^[0-9]+\.[0-9]+/) ||
        stream.match(/^[0-9]+/)
      ) {
        return "number";
      }

      if (stream.match(/^(True|False|Nil|Ok|Error)\b/)) return "atom";

      const word = stream.match(/^[A-Za-z_][A-Za-z0-9_]*/);

      if (word) {
        if (keywords.has(word[0])) return "keyword";
        if (/^[A-Z]/.test(word[0])) return "typeName";
        return "variableName";
      }

      if (
        stream.match(
          /^(\+\.|-\.|\*\.|\/\.|<=\.|>=\.|<\.|>\.|==|!=|->|<-|\|>|=)/,
        )
      ) {
        return "operator";
      }

      stream.next();
      return null;
    },

    languageData: {
      commentTokens: { line: "//" },
    },
  });
}

function loadCodeMirror() {
  if (cmModulePromise) return cmModulePromise;

  const V = "6";

  cmModulePromise = Promise.all([
    import(`https://esm.sh/@codemirror/view@${V}`),
    import(`https://esm.sh/@codemirror/state@${V}`),
    import(`https://esm.sh/@codemirror/commands@${V}`),
    import(`https://esm.sh/@codemirror/language@${V}`),
    import(`https://esm.sh/@codemirror/autocomplete@${V}`),
    import("https://esm.sh/@lezer/highlight@1"),
  ]).then(([view, state, commands, language, autocomplete, highlight]) => {
    const { tags: t } = highlight;

    const theme = view.EditorView.theme(
      {
        "&": {
          color: "#d4c5a0",
          backgroundColor: "#0d0d1a",
          height: "100%",
        },
        ".cm-content": {
          fontFamily: "monospace",
          fontSize: "13px",
          padding: "16px 0",
        },
        ".cm-gutters": {
          backgroundColor: "#0d0d1a",
          color: "#3a3a5e",
          border: "none",
        },
        ".cm-activeLine": {
          backgroundColor: "#16162c",
        },
        ".cm-activeLineGutter": {
          backgroundColor: "#16162c",
        },
        "&.cm-focused .cm-matchingBracket": {
          backgroundColor: "#2a4a3a",
          color: "#fff",
        },
        ".cm-scroller": {
          overflow: "auto",
        },
        "&.cm-focused": {
          outline: "1px solid #6a6aaa",
        },
      },
      { dark: true },
    );

    const highlightStyle = language.HighlightStyle.define([
      { tag: t.keyword, color: "#c792ea" },
      { tag: t.comment, color: "#6a7a6a", fontStyle: "italic" },
      { tag: t.string, color: "#c3e88d" },
      { tag: t.number, color: "#f78c6c" },
      { tag: [t.atom, t.bool], color: "#82aaff" },
      { tag: t.typeName, color: "#ffcb6b" },
      { tag: t.variableName, color: "#d4c5a0" },
      { tag: t.operator, color: "#89ddff" },
    ]);

    const gleam = defineGleam(language.StreamLanguage);

    function create(parent, doc, onChange) {
      const updateListener = view.EditorView.updateListener.of((update) => {
        if (update.docChanged) {
          onChange(update.state.doc.toString());
        }
      });

      const startState = state.EditorState.create({
        doc,
        extensions: [
          view.lineNumbers(),
          view.highlightActiveLine(),
          view.highlightActiveLineGutter(),
          commands.history(),
          view.drawSelection(),
          language.indentOnInput(),
          language.indentUnit.of("  "),
          language.bracketMatching(),
          autocomplete.closeBrackets(),
          language.syntaxHighlighting(highlightStyle),
          gleam,
          view.keymap.of([
            ...autocomplete.closeBracketsKeymap,
            ...commands.defaultKeymap,
            ...commands.historyKeymap,
            commands.indentWithTab,
          ]),
          theme,
          view.EditorView.lineWrapping,
          updateListener,
        ],
      });

      return new view.EditorView({
        state: startState,
        parent,
      });
    }

    return { create };
  });

  return cmModulePromise;
}

function waitForElement(id, maxFrames) {
  return new Promise((resolve) => {
    let tries = 0;

    const check = () => {
      const el = document.getElementById(id);

      if (el) return resolve(el);
      if (tries++ >= maxFrames) return resolve(null);

      requestAnimationFrame(check);
    };

    check();
  });
}

function reattachEditor() {
  if (!cmView || cmView.dom.isConnected) return;

  const el = document.getElementById("code-editor");
  if (!el) return;

  el.replaceChildren(cmView.dom);
  cmView.requestMeasure();

  if (document.activeElement === document.body) {
    cmView.focus();
  }
}

export function mountEditor(initialText, onChange) {
  // Only the newest mount is allowed to create an editor or report edits.
  const version = ++cmMountVersion;

  if (cmView) {
    cmView.destroy();
    cmView = null;
  }

  if (!cmObserver) {
    cmObserver = new MutationObserver(reattachEditor);
    cmObserver.observe(document.body, {
      childList: true,
      subtree: true,
    });
  }

  waitForElement("code-editor", 120)
    .then((mount) => {
      if (!mount || version !== cmMountVersion) return;

      return loadCodeMirror().then((CM) => {
        if (version !== cmMountVersion) return;

        const el = document.getElementById("code-editor");
        if (!el) return;

        el.replaceChildren();

        cmView = CM.create(el, initialText, (text) => {
          if (version === cmMountVersion) {
            onChange(text);
          }
        });
      });
    })
    .catch((error) => {
      console.error("CodeMirror failed to load:", error);
    });
}