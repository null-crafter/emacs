;;; -*- lexical-binding: t -*-
;;;
;;; Emacs Bedrock
;;;
;;; Extra config: Development tools

;;; Usage: Append or require this file from init.el for some software
;;; development-focused packages.
;;;
;;; It is **STRONGLY** recommended that you use the base.el config if you want to
;;; use Eglot. Lots of completion things will work better.
;;;
;;; This will try to use tree-sitter modes for many languages. Please run
;;;
;;;   M-x treesit-install-language-grammar
;;;
;;; Before trying to use a treesit mode.

;;; Contents:
;;;
;;;  - Built-in config for developers
;;;  - Version Control
;;;  - Common file types
;;;  - Eglot, the built-in LSP client for Emacs
;;;  - Python virtualenvs
;;;  - Templating

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Built-in config for developers
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package emacs
  :config
  ;; Code folding config
  ;(setopt hs-show-indicators t)         ; Show collapse indicators in margin
  ;(setopt hs-display-lines-hidden t)    ; Show number of collapsed lines


  ;; Treesitter config

  ;; Enable tree-sitter in all available modes
  (setopt treesit-enabled-modes t)

  ;; Amount to highlight: integer between 1-4; 4 is max highlighting
  (setopt treesit-font-lock-level 3)

  ;; What to do if language grammar not installed: default is `ask';
  ;; other options are `always', and `ask-dir'.
  (setopt treesit-auto-install-grammar 'ask)

  :hook
  ;; Auto parenthesis matching
  ((prog-mode . electric-pair-mode)))

(use-package project
  :custom
  (project-mode-line t))                ; show project name in modeline

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Version Control
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Magit: best Git client to ever exist
(use-package magit
  :bind (("C-x g" . magit-status)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Common file types
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package markdown-mode
  :hook ((markdown-mode . visual-line-mode)))

(use-package yaml-mode)

(use-package json-mode)

;; .mjs/.cjs open like .js, .mts/.cts like .ts
(add-to-list 'auto-mode-alist '("\\.[cm]js\\'" . javascript-mode))
(add-to-list 'auto-mode-alist '("\\.[cm]ts\\'" . typescript-ts-mode-maybe))

;; Emacs ships with a lot of popular programming language modes. If it's not
;; built in, you're almost certain to find a mode for the language you're
;; looking for with a quick Internet search.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Eglot, the built-in LSP client for Emacs
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Helpful resources:
;;
;;  - https://www.masteringemacs.org/article/seamlessly-merge-multiple-documentation-sources-eldoc

(use-package eglot
  ;; no :ensure t here because it's built-in

  ;; Configure hooks to automatically turn-on eglot for selected modes.
  ;; python-base-mode also covers python-ts-mode, which .py files open in.
  :hook
  ((python-base-mode . eglot-ensure)
   ;; not js-base-mode: MELPA's json-mode (.json) derives from it
   ((js-ts-mode typescript-ts-base-mode) . eglot-ensure)
   (rust-ts-mode . eglot-ensure))       ; eglot ships the rust-analyzer entry

  :custom
  (eglot-send-changes-idle-time 0.1)
  (eglot-extend-to-xref t)              ; activate Eglot in referenced non-project files

  :config
  ;; Avoid changing line heights if your font is wonky. See
  ;; https://github.com/joaotavora/eglot/discussions/1492
  (setopt eglot-code-action-indicator "h")

  (fset #'jsonrpc--log-event #'ignore)  ; massive perf boost---don't log every event
  ;; Sometimes you need to tell Eglot where to find the language server
  ; (add-to-list 'eglot-server-programs
  ;              '(haskell-mode . ("haskell-language-server-wrapper" "--lsp")))


  ;; ty and jedi in one buffer through the rass multiplexer. Log level `info'
  ;; keeps server errors but drops rass's copy of every LSP message.
  (add-to-list 'eglot-server-programs
               '((python-base-mode :language-id "python")
                 . ("rass" "--log-level" "info"
                    "--" "ty" "server"))
	       )

  ;; JS/TS: TypeScript 7's built-in language server
  (add-to-list 'eglot-server-programs
               '(((js-ts-mode :language-id "javascript")
                  (tsx-ts-mode :language-id "typescriptreact")
                  (typescript-ts-mode :language-id "typescript"))
                 . ("tsc" "--lsp" "--stdio")))

  ;; You can set various options for each language server. For
  ;; example, you can raise the number of completions surfaced by a
  ;; given langauge server to Emacs:
  (setopt eglot-workspace-configuration
	  '((haskell (maxCompletions . 100))
	    (elixir  (maxCompletions . 100))))
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Python virtualenvs
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; pet finds each project's virtualenv (VIRTUAL_ENV, .venv, poetry, pipenv,
;; conda, pyenv...); M-x pet-verify-setup shows what it picked. Reading
;; pyproject.toml, Pipfile and environment.yml needs the `dasel' program.
(defun my/pet-export-venv ()
  "Hand pet's virtualenv to this buffer's subprocesses, like bin/activate."
  (pet-eglot-teardown)            ; pet tunes eglot by server name; misfires behind rass
  (kill-local-variable 'exec-path)
  (kill-local-variable 'process-environment)
  (when-let* ((venv (and pet-mode python-shell-virtualenv-root))
              (bin (expand-file-name "bin" venv)))
    (setq-local exec-path (cons bin exec-path))
    (setq-local process-environment
                (append (list (concat "VIRTUAL_ENV=" (directory-file-name venv))
                              (concat "PATH=" bin path-separator (getenv "PATH")))
                        process-environment))))

(use-package pet
  :defer t
  :custom
  (pet-debug t)                         ; report detection errors, don't swallow them
  :init
  (add-hook 'python-base-mode-hook #'pet-mode -10)
  :config
  (add-hook 'pet-after-buffer-local-vars-setup #'my/pet-export-venv)
  (add-hook 'pet-before-buffer-local-vars-teardown #'my/pet-export-venv))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Templating
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package tempel
  ;; By default, tempel looks at the file "templates" in
  ;; user-emacs-directory, but you can customize that with the
  ;; tempel-path variable:
  ;; :custom
  ;; (tempel-path (concat user-emacs-directory "custom_template_file"))
  :bind (("M-*" . tempel-insert)
         ("M-+" . tempel-complete)
         :map tempel-map
         ("C-c RET" . tempel-done)
         ("C-<down>" . tempel-next)
         ("C-<up>" . tempel-previous)
         ("M-<down>" . tempel-next)
         ("M-<up>" . tempel-previous))
  :init
  ;; Make a function that adds the tempel expansion function to the
  ;; list of completion-at-point-functions (capf).
  (defun tempel-setup-capf ()
    (add-hook 'completion-at-point-functions #'tempel-expand -1 'local))
  ;; Put tempel-expand on the list whenever you start programming or
  ;; writing prose.
  (add-hook 'prog-mode-hook 'tempel-setup-capf)
  (add-hook 'text-mode-hook 'tempel-setup-capf))
