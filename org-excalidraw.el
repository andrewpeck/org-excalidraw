;;; org-excalidraw.el --- Tools for working with excalidraw drawings -*- lexical-binding: t; -*-
;; Copyright (C) 2022 David Wilson

;; Author:  David Wilson <wdavew@gmail.com>
;; URL: https://github.com/wdavew/org-excalidraw
;; Created: 2022
;; Version: 0.1.0
;; Keywords: convenience, outlines
;; Package-Requires: ((org "9.3") (emacs "26.1"))

;; Permission is hereby granted, free of charge, to any person
;; obtaining a copy of this software and associated documentation
;; files (the "Software"), to deal in the Software without
;; restriction, including without limitation the rights to use, copy,
;; modify, merge, publish, distribute, sublicense, and/or sell copies
;; of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
;; BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
;; ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
;; CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:
;;; org-excalidraw.el is a package to for embedding excalidraw drawings into Emacs.
;;; it adds an org-mode link type for excalidraw files to support inline display
;;; and opening the diagrams from Emacs for editing.

;;; Code:
(require 'cl-lib)
(require 'filenotify)
(require 'org-id)
(require 'ol)

(defun org-excalidraw--default-base ()
  "Get default JSON template used for new excalidraw files."
  "{
    \"type\": \"excalidraw\",
    \"version\": 2,
    \"source\": \"https://excalidraw.com\",
    \"elements\": [],
    \"appState\": {
      \"gridSize\": null,
      \"viewBackgroundColor\": \"#ffffff\"
    },
    \"files\": {}
  }
")

(defgroup org-excalidraw nil
  "Customization options for org-excalidraw."
  :group 'org
  :prefix "org-excalidraw-")

(defcustom org-excalidraw-directory "~/org-excalidraw"
  "Directory to store excalidraw files."
  :type 'string
  :group 'org-excalidraw)

(defcustom org-excalidraw-type-prefix "excalidraw"
  "Prefix to use for attached excalidraw svg files.

Org mode natively understands file and attachment types and processes
them as images. Code in the org-yt package enables user defined image
prefixes, in which case this could be set to excalidraw."

  :type 'string
  :group 'org-excalidraw)

(defcustom org-excalidraw-base (org-excalidraw--default-base)
  "JSON string representing base excalidraw template for new files."
  :type 'string
  :group 'org-excalidraw)

(defun org-excalidraw--validate-excalidraw-file (path)
  "Validate the excalidraw file at PATH is usable."
  (unless (string-suffix-p ".excalidraw" path)
    (error
     "Excalidraw file must have .excalidraw extension")))

(defun org-excalidraw--cmd-to-svg (path)
  "Construct shell cmd for converting excalidraw file with PATH to svg."
  (call-process  "excalidraw_export" nil 0 nil path "--rename_fonts=true"))

(defun org-excalidraw--cmd-open (path os-type)
  "Start process to open excalidraw file with PATH for OS-TYPE."
  (call-process
   (if (boundp 'shell-command-guess-open)
       shell-command-guess-open
       (if (eq os-type 'darwin) "open" "xdg-open"))
   nil 0 nil (shell-quote-argument path)))

(defun org-excalidraw--open-file-from-svg (path &optional _)
  "Open corresponding .excalidraw file for svg located at PATH."
  (let ((excal-file-path (string-remove-suffix ".svg" path)))
    (org-excalidraw--validate-excalidraw-file excal-file-path)
    (org-excalidraw--cmd-open excal-file-path system-type)))

(defun org-excalidraw--handle-file-change (event)
  "Handle file update EVENT to convert files to svg."
  (when (string-equal (cadr event)  "renamed")
    (let ((filename (if (eq (cadr event) 'changed)
                        (caddr event)
                      (cadddr event))))
      (when (string-suffix-p ".excalidraw" filename)
        (org-excalidraw--cmd-to-svg filename)))))

(defun org-excalidraw-uuid-function ()
  "Function to call to generate a unique ID for org-excalidraw files.

This defaults to org-id-uuid but could be any function, e.g. one which
returns the name of the current file appended with a timestamp, etc"
   (org-id-uuid))

;;;###autoload
(defun org-excalidraw-create-drawing ()
  "Create an excalidraw drawing and insert an `org-mode' link to it at Point."
  (interactive)
  (let* ((filename (concat (org-excalidraw-uuid-function) ".excalidraw"))
         (path (expand-file-name filename org-excalidraw-directory))
         (link (concat "[[" org-excalidraw-type-prefix ":" path ".svg]]")))
    (org-excalidraw--validate-excalidraw-file path)
    (insert link)
    (with-temp-file path (insert org-excalidraw-base))
    (org-excalidraw--cmd-open path system-type)))


;;;###autoload
(defun org-excalidraw-initialize ()
  "Setup excalidraw.el. Call this after `org-mode' initialization."
  (interactive)
  (unless (file-directory-p org-excalidraw-directory)
    (error
     "Excalidraw directory %s does not exist"
     org-excalidraw-directory))
  (file-notify-add-watch org-excalidraw-directory '(change) 'org-excalidraw--handle-file-change)

  ;; register a handler for .excalidraw.svg file extensions
  (push (cons "\\.excalidraw.svg\\'" 'org-excalidraw--open-file-from-svg) org-file-apps)

  ;; this is only valid when org-display-user-inline-images is defined
  ;; e.g. via the org-yt package
  (when (and (fboundp #'org-link-preview)
             (string= "excalidraw" org-excalidraw-type-prefix))
    (org-link-set-parameters org-excalidraw-type-prefix
                             :follow 'org-excalidraw--open-file-from-svg
                             :preview (lambda (_protocol link _desc)
                                          (when (file-exists-p link)
                                                (with-temp-buffer
                                                  (insert-file-contents-literally link)
                                                  (buffer-substring-no-properties
                                                   (point-min)
                                                   (point-max))))))))


(provide 'org-excalidraw)
;;; org-excalidraw.el ends here
