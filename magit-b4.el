;;; magit-b4.el --- Magit extension for b4  -*- lexical-binding: t; -*-

;; Author: Julien Masson <massonju.eseo@gmail.com>
;; URL: https://github.com/JulienMasson/magit-b4

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

(require 'magit)
(require 'transient)

(defgroup magit-b4 nil
  "Magit extension for b4"
  :prefix "magit-b4"
  :group 'magit-extensions)

(defcustom magit-b4-executable (executable-find "b4")
  "The b4 executable."
  :group 'magit-b4
  :type 'string)

(defcustom magit-b4-send-default-args (list "--no-sign")
  "Default arguments for b4 send command."
  :group 'magit-b4
  :type 'list)

(defun magit-b4-call-process (cmd args)
  (let ((args (append (list cmd) args)))
    (apply #'magit-call-process magit-b4-executable args)))

(defun magit-b4-shazam (msgid)
  (interactive (list (read-string "msgid: ")))
  (magit-b4-call-process "shazam" (list msgid))
  (magit-refresh))

(defun magit-b4-check ()
  (interactive)
  (compilation-start (concat magit-b4-executable " prep --check")))

(defun magit-b4-edit-cover-letter ()
  (interactive)
  (let ((cmd (concat magit-b4-executable " prep --edit-cover"))
        (with-editor-emacsclient-executable nil))
    (with-editor-async-shell-command cmd)))

;; Workaround for edit cover letter
;; The COMMIT_EDITMSG is placed in tmp directory (not a magit-toplevel).
;; Thus magit-commit-diff raise an error (with-editor-filter-visit-hook).
(defun magit-commit-diff--check-toplevel (fn &rest args)
  (when (magit-toplevel)
    (apply fn args)))

(advice-add 'magit-commit-diff :around #'magit-commit-diff--check-toplevel)

(defun magit-b4-prep (series-name &optional fork-point msgid)
  (interactive (list (read-string "New branch name: ")
                     (read-string "Fork point (leave empty for HEAD): ")
                     (read-string "Use thread msgid (optional): ")))
  (let ((args (list (concat "--new=" series-name)
                    (unless (string-empty-p fork-point)
                      (concat "--fork-point=" fork-point))
                    (unless (string-empty-p msgid)
                      (concat "--from-thread=" msgid)))))
    (magit-b4-call-process "prep" (delq nil args))
    (magit-refresh)))

(defun magit-b4-add-to-cc-cover-leter ()
  (interactive)
  (magit-b4-call-process "prep" (list "--auto-to-cc"))
  (magit-refresh))

(defun magit-b4-send ()
  (interactive)
  (let ((args (transient-args 'magit-b4-send-dispatch)))
    (magit-b4-call-process "send" (delq nil args))))

(transient-define-prefix magit-b4-send-dispatch ()
  "Dispatch a b4 send command."
  :value magit-b4-send-default-args
  ["Arguments"
   ("-d" "Do not send, just dump out raw messages" "--dry-run")
   ("-r" "Send everything to yourself"             "--reflect")
   ("-s" "Do not add crypto signature header"      "--no-sign")]
  [["Actions"
    ("s" "Submit work for review" magit-b4-send)]])

(transient-define-prefix magit-b4-dispatch ()
  "Dispatch a b4 command."
  [["Actions"
    ("a" "Applies series to current tree" magit-b4-shazam)
    ("c" "Run checks on the series"       magit-b4-check)
    ("e" "Edit the cover letter"          magit-b4-edit-cover-letter)
    ("p" "Prep patch series"              magit-b4-prep)
    ("s" "Submit work for review"         magit-b4-send-dispatch)
    ("t" "Add To and Cc in cover letter"  magit-b4-add-to-cc-cover-leter)]])

(provide 'magit-b4)
