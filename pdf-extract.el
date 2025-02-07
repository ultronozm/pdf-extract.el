;;; pdf-extract.el --- Extract page ranges from PDF files  -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Paul D. Nelson

;; Author: Paul D. Nelson <nelson.paul.david@gmail.com>
;; Version: 0.1
;; URL: https://github.com/ultronozm/pdf-extract.el
;; Package-Requires: ((emacs "27.1"))
;; Keywords: files, multimedia

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides a simple interface for extracting page ranges
;; from PDF files using the qpdf command-line tool.  The main entry
;; point is the command `pdf-extract-pages'.

;;; Code:

(defgroup pdf-extract nil
  "Extract page ranges from PDF files."
  :group 'files)

(defcustom pdf-extract-directory "~/pdf-extracts"
  "Directory for storing PDF page extracts.
If nil, store extracts in the same directory as the source PDF."
  :type '(choice (directory :tag "Dedicated directory")
                 (const :tag "Same as source" nil)))

;;;###autoload
(defun pdf-extract-pages (pdf-file page-range)
  "Extract pages from PDF-FILE according to PAGE-RANGE.
PAGE-RANGE is a string like \"1-3\" or \"1,3-5\".
Opens the resulting PDF and returns its filename."
  (interactive
   (let* ((default-pdf (when (derived-mode-p 'pdf-view-mode)
                         (expand-file-name (buffer-file-name))))
          ;; Use read-file-name more simply
          (pdf (expand-file-name
                (read-file-name
                 "PDF file: "
                 (when default-pdf (file-name-directory default-pdf))
                 default-pdf)))
          (range (read-string "Page range (e.g., \"1-3\" or \"1,3-5\"): ")))
     (list pdf range)))

  ;; Create extract directory if needed
  (when pdf-extract-directory
    (unless (file-exists-p pdf-extract-directory)
      (make-directory pdf-extract-directory t)))

  (let* ((output-file (format "%s-pages-%s.pdf"
                              (file-name-sans-extension
                               (file-name-nondirectory pdf-file))
                              (replace-regexp-in-string "[,]" "-" page-range)))
         (output-path (expand-file-name output-file
                                        (or pdf-extract-directory
                                            (file-name-directory pdf-file))))
         (error-buffer (generate-new-buffer "*qpdf-error*")))

    ;; Handle filename collisions
    (let ((i 1))
      (while (file-exists-p output-path)
        (setq output-path
              (expand-file-name
               (format "%s-pages-%s-%d.pdf"
                       (file-name-sans-extension
                        (file-name-nondirectory pdf-file))
                       (replace-regexp-in-string "[,]" "-" page-range)
                       i)
               (or pdf-extract-directory
                   (file-name-directory pdf-file))))
        (setq i (1+ i))))

    ;; Run qpdf
    (unwind-protect
        (let ((status (call-process "qpdf" nil error-buffer nil
                                    "--empty"
                                    "--pages" (expand-file-name pdf-file) page-range
                                    "--"
                                    output-path)))
          (unless (= status 0)
            (with-current-buffer error-buffer
              (error "Command `qpdf' failed: %s" (buffer-string)))))
      (kill-buffer error-buffer))

    ;; Open the new PDF and return its path
    (when (called-interactively-p 'interactive)
      (find-file output-path))

    output-path))

(provide 'pdf-extract)
;;; pdf-extract.el ends here
