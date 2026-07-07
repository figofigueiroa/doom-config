;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
;;
;;
;;; ---------------------------------------------------------------
;;; Eglot + csharp-ls (Roslyn) para C#, com decompilação
;;; ---------------------------------------------------------------
;;
(after! eglot
  (add-to-list 'eglot-server-programs
               '((csharp-mode csharp-ts-mode) . ("roslyn-language-server"
                                                 "--stdio"
                                                 "--autoLoadProjects"
                                                 "--logLevel" "Information")))
  (add-to-list 'eglot-server-programs
               '((typescript-mode typescript-ts-mode tsx-ts-mode) . ("typescript-language-server" "--stdio"))))

;;; ---------------------------------------------------------------
;;; Diagnósticos (Flymake, nativo do eglot)
;;; ---------------------------------------------------------------
;; Eglot usa flymake em vez de flycheck. Se quiser manter a UI do flycheck
;; (fringe icons, etc.) só pra não perder o hábito visual do lsp-ui, dá pra
;; usar o pacote `flycheck-eglot' (não vem com o Doom, precisaria adicionar
;; em packages.el). Por padrão deixamos no flymake, que já é suficiente e
;; fica mais leve.
(after! flymake
  (setq flymake-no-changes-timeout 0.3))

;;; ---------------------------------------------------------------
;;; Debugger (dap-mode + Roslyn/netcoredbg)
;;; ---------------------------------------------------------------

(after! dap-mode
  (require 'dap-netcore)
  ;; Caminho cross-platform: doom-data-dir aponta para ~/.local/share/doom/ no Linux
  ;; e ~/AppData/Roaming/doom/ no Windows. O dap-netcore-update-debugger instala aqui.
  (setq dap-netcore-install-dir (expand-file-name "netcoredbg/" doom-data-dir))
  (dap-ui-mode 1)
  (dap-auto-configure-mode 1)

  (defun figo/dotnet-project-name ()
    "Pega o nome do projeto a partir da raiz (ex: MinhaApp)."
    (file-name-nondirectory (directory-file-name (projectile-project-root))))

  (defun figo/dotnet-find-main-dll ()
    "Encontra a DLL da aplicação, ignorando o projeto .Tests."
    (let* ((root (projectile-project-root))
           (proj-name (figo/dotnet-project-name))
           (dlls (directory-files-recursively root "\\.dll$"))
           ;; Normaliza separadores para forward-slash (compatibilidade Windows/Linux)
           (normalize (lambda (p) (replace-regexp-in-string "\\\\" "/" p)))
           (bin-dlls (seq-filter
                      (lambda (p) (string-match-p "/bin/Debug/" (funcall normalize p)))
                      dlls))
           (app-dlls (seq-remove
                      (lambda (p) (string-match-p "\\.Tests/" (funcall normalize p)))
                      bin-dlls)))
      (or (car (seq-filter
                (lambda (p) (string-match-p (concat proj-name "\\.dll$") p))
                app-dlls))
          (car app-dlls)
          (error "DLL da aplicação '%s' não encontrada" proj-name))))

  (defun figo/dotnet-find-test-dll ()
    "Encontra a DLL do projeto de testes."
    (let* ((root (projectile-project-root))
           (dlls (directory-files-recursively root "\\.dll$"))
           ;; Normaliza separadores para forward-slash (compatibilidade Windows/Linux)
           (normalize (lambda (p) (replace-regexp-in-string "\\\\" "/" p)))
           (bin-dlls (seq-filter
                      (lambda (p) (string-match-p "/bin/Debug/" (funcall normalize p)))
                      dlls))
           (test-dlls (seq-filter
                       (lambda (p) (string-match-p "\\.Tests/" (funcall normalize p)))
                       bin-dlls)))
      (or (car test-dlls)
          (error "DLL de testes não encontrada"))))

  (dap-register-debug-template
   "NetCore :: App"
   (list :type "coreclr" :request "launch" :name "NetCore :: App"
         :program 'figo/dotnet-find-main-dll
         :cwd '(lambda () (projectile-project-root))))

  (dap-register-debug-template
   "NetCore :: Tests"
   (list :type "coreclr" :request "launch" :name "NetCore :: Tests"
         :program 'figo/dotnet-find-test-dll
         :cwd '(lambda () (projectile-project-root)))))

;;; ---------------------------------------------------------------
;;; Compatibilidade Windows
;;; ---------------------------------------------------------------

;; bash-language-server não funciona no Windows nativo sem WSL;
;; desabilita LSP para sh-mode nesse ambiente.
(when (eq system-type 'windows-nt)
  (add-hook! sh-mode (lsp-mode -1)))

;;; ---------------------------------------------------------------
;;; Bookmarks (bm.el)
;;; ---------------------------------------------------------------

(use-package! bm
  :config
  (setq bm-marker 'bm-marker-right)
  (map! :leader
        "t b" #'bm-toggle
        "] b" #'bm-next
        "[ b" #'bm-previous))
;;; ---------------------------------------------------------------
;;; evil-textobj-tree-sitter
;;; ---------------------------------------------------------------
(use-package! evil-textobj-tree-sitter
  :after evil
  :config
  ;; Bind standard text objects for structural selection
  (define-key evil-inner-text-objects-map "f" (evil-textobj-tree-sitter-get-textobj "function.inner"))
  (define-key evil-outer-text-objects-map "f" (evil-textobj-tree-sitter-get-textobj "function.outer"))

  (define-key evil-inner-text-objects-map "c" (evil-textobj-tree-sitter-get-textobj "class.inner"))
  (define-key evil-outer-text-objects-map "c" (evil-textobj-tree-sitter-get-textobj "class.outer"))

  (define-key evil-inner-text-objects-map "l" (evil-textobj-tree-sitter-get-textobj "loop.inner"))
  (define-key evil-outer-text-objects-map "l" (evil-textobj-tree-sitter-get-textobj "loop.outer")))
