/*                                                              -*-Javascript-*-

 Copyright (C) 2015 LiveCode Ltd.

 This file is part of LiveCode.

 LiveCode is free software; you can redistribute it and/or modify it under
 the terms of the GNU General Public License v3 as published by the Free
 Software Foundation.

 LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
 WARRANTY; without even the implied warranty of MERCHANTABILITY or
 FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 for more details.

 You should have received a copy of the GNU General Public License
 along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

// The engine's dialogs on the web.
//
// answer, ask, ask password, answer color, ask file and the file
// pickers of answer file and answer folder are dialogs of the page: an
// element over the whole page, so the stacks' windows under it get no
// clicks while it is open, as with a modal dialog on the desktop. The
// engine waits for it in a loop (em-dc.cpp), which yields to the
// browser, so the page goes on running and the engine's timers fire;
// a click on one of the dialog's buttons resumes the engine.
//
// When the engine cannot wait (a handler that the page calls), the
// browser's own alert(), confirm() and prompt() are used instead, as
// LiveCode's HTML5 engine always did: they block the page until they
// are answered.
//
// A file that the user picks is copied into the engine's file system,
// into /uploads, and answer file returns that copy's path. ask file
// returns a path in /downloads: a file written there is offered to the
// user as a download when it is closed (em-filehandle.cpp).

mergeInto(LibraryManager.library, {

    $LiveCodeDialog__deps: ['$LiveCodeUtil', '$LiveCodeAsync', '$FS'],
    $LiveCodeDialog: {

        // ----------------------------------------------------------------
        // The browser's own dialogs
        // ----------------------------------------------------------------

        showAlert: function(message_buffer, message_length) {
            var message = LiveCodeUtil.stringFromUTF16(message_buffer, message_length);
            alert(message);
            return 0;
        },

        showConfirm: function(message_buffer, message_length) {
            var message = LiveCodeUtil.stringFromUTF16(message_buffer, message_length);

            var result = confirm(message);
            return result;
        },

          showPrompt: function(message_buffer, message_length, default_buffer, default_length, return_buffer, return_length) {
              var message = LiveCodeUtil.stringFromUTF16(message_buffer, message_length);
              var default_value = LiveCodeUtil.stringFromUTF16(default_buffer, default_length);

              // Prompt the user for some text input. If cancelled, will return null.
              var result = prompt(message, default_value);
              if (result === null) {
                  return false;
              }

              // Allocate a buffer and store encode the string into it
              var buffer = LiveCodeUtil.stringToUTF16(result);
              var buffer_length = result.length*2;
              {{{ makeSetValue('return_buffer', '0', 'buffer', 'i32') }}};
              {{{ makeSetValue('return_length', '0', 'buffer_length', 'i32') }}};

              return true;
          },

        // ----------------------------------------------------------------
        // The page's dialogs
        // ----------------------------------------------------------------

        // The kinds of dialog (enum MCEmscriptenDialogKind in em-dc.h)
        kAnswer: 0,
        kAsk: 1,
        kPassword: 2,
        kColor: 3,
        kChoose: 4,
        kSave: 5,

        // The icons of an answer dialog by its type (0: none, then
        // kMCAnswerDialogType* plus one): information (U+2139), question,
        // warning and error (U+2716)
        _icons: ['', '\u2139', '?', '!', '\u2716'],

        // Open dialogs by id: {open, button, text}
        _dialogs: {},
        _nextId: 1,

        _styled: false,

        // The look of the dialogs. Pages can restyle them: every class
        // name starts with "oxt-dialog".
        _addStyles: function() {
            if (LiveCodeDialog._styled) {
                return;
            }
            LiveCodeDialog._styled = true;
            var style = document.createElement('style');
            style.textContent =
                '.oxt-dialog-backdrop{position:fixed;left:0;top:0;right:0;bottom:0;z-index:2147483000;' +
                'display:flex;align-items:center;justify-content:center;background:rgba(0,0,0,0.25)}' +
                '.oxt-dialog{box-sizing:border-box;min-width:300px;max-width:min(560px,calc(100vw - 32px));' +
                'max-height:calc(100vh - 32px);overflow:auto;padding:18px 20px 16px;border-radius:8px;' +
                'background:#fff;color:#1d1d1f;box-shadow:0 10px 40px rgba(0,0,0,0.35);' +
                'font:14px/1.4 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;text-align:left}' +
                '.oxt-dialog-title{font-weight:600;margin:0 0 8px}' +
                '.oxt-dialog-body{display:flex;gap:14px;align-items:flex-start}' +
                '.oxt-dialog-icon{flex:none;width:32px;height:32px;border-radius:50%;display:flex;' +
                'align-items:center;justify-content:center;font-weight:700;font-size:18px;color:#fff;background:#3478f6}' +
                '.oxt-dialog-icon-3{background:#e8a317}.oxt-dialog-icon-4{background:#d93025}' +
                '.oxt-dialog-message{flex:1;white-space:pre-wrap;overflow-wrap:anywhere;margin:4px 0 0}' +
                '.oxt-dialog-input{box-sizing:border-box;width:100%;margin:12px 0 0;padding:6px 8px;' +
                'border:1px solid #b0b0b5;border-radius:5px;font:inherit;color:inherit;background:#fff}' +
                '.oxt-dialog-color{display:block;width:72px;height:40px;margin:12px 0 0;padding:0;border:0;background:none}' +
                '.oxt-dialog-buttons{display:flex;flex-wrap:wrap;gap:8px;justify-content:flex-end;margin:18px 0 0}' +
                '.oxt-dialog-button{min-width:76px;padding:6px 14px;border:1px solid #b0b0b5;border-radius:6px;' +
                'background:#f5f5f7;color:inherit;font:inherit;cursor:pointer}' +
                '.oxt-dialog-button:focus-visible{outline:2px solid #3478f6;outline-offset:2px}' +
                '.oxt-dialog-default{background:#3478f6;border-color:#3478f6;color:#fff}' +
                '@media (prefers-color-scheme: dark){.oxt-dialog{background:#2c2c2e;color:#f2f2f7}' +
                '.oxt-dialog-input{background:#1c1c1e;border-color:#5a5a5e}' +
                '.oxt-dialog-button{background:#3a3a3c;border-color:#5a5a5e}' +
                '.oxt-dialog-default{background:#3478f6;border-color:#3478f6}}';
            document.head.appendChild(style);
        },

        _element: function(tag, className, parent) {
            var element = document.createElement(tag);
            if (className) {
                element.className = className;
            }
            if (parent) {
                parent.appendChild(element);
            }
            return element;
        },

        // Opens a dialog and returns its id. The engine waits until
        // isOpen(id) is false, then reads button(id) (the index of the
        // button clicked, or -1 when cancelled) and text(id).
        //
        // kind: one of the kinds above
        // type: the icon of an answer dialog (0 for none, then
        //   information, question, warning and error), or 1 if the text
        //   of an ask dialog is a hint
        // buttons: the labels; the last one is the default button
        // text: an ask dialog's initial text (or hint), or an answer
        //   color dialog's initial colour (#rrggbb)
        // onChoose: called in the click on the button with the index
        //   chooseButton (kChoose: which opens the file picker, and does
        //   not close the dialog)
        open: function(kind, type, title, message, buttons, text, onChoose, chooseButton) {
            LiveCodeDialog._addStyles();

            var id = LiveCodeDialog._nextId++;
            var state = {'open': true, 'button': -1, 'text': '', 'element': null,
                         'focus': document.activeElement, 'detached': false};
            LiveCodeDialog._dialogs[id] = state;

            var backdrop = LiveCodeDialog._element('div', 'oxt-dialog-backdrop', null);
            var dialog = LiveCodeDialog._element('div', 'oxt-dialog', backdrop);
            dialog.setAttribute('role', kind == LiveCodeDialog.kAnswer && type >= 3 ? 'alertdialog' : 'dialog');
            dialog.setAttribute('aria-modal', 'true');
            state.element = backdrop;

            if (title) {
                var heading = LiveCodeDialog._element('div', 'oxt-dialog-title', dialog);
                heading.textContent = title;
                dialog.setAttribute('aria-label', title);
            }

            var body = LiveCodeDialog._element('div', 'oxt-dialog-body', dialog);
            if (kind == LiveCodeDialog.kAnswer && type > 0 && type < LiveCodeDialog._icons.length) {
                var icon = LiveCodeDialog._element('div', 'oxt-dialog-icon oxt-dialog-icon-' + type, body);
                icon.textContent = LiveCodeDialog._icons[type];
                icon.setAttribute('aria-hidden', 'true');
            }
            var column = LiveCodeDialog._element('div', '', body);
            column.style.flex = '1';
            column.style.minWidth = '0';
            if (message) {
                var paragraph = LiveCodeDialog._element('p', 'oxt-dialog-message', column);
                LiveCodeDialog._setMessage(paragraph, message);
            }

            var input = null;
            switch (kind) {
            case LiveCodeDialog.kAsk:
            case LiveCodeDialog.kPassword:
            case LiveCodeDialog.kSave:
                input = LiveCodeDialog._element('input', 'oxt-dialog-input', column);
                input.type = kind == LiveCodeDialog.kPassword ? 'password' : 'text';
                if (kind != LiveCodeDialog.kSave && type == 1) {
                    input.placeholder = text;
                } else {
                    input.value = text;
                }
                input.setAttribute('autocomplete', 'off');
                if (message) {
                    input.setAttribute('aria-label', message);
                }
                break;
            case LiveCodeDialog.kColor:
                input = LiveCodeDialog._element('input', 'oxt-dialog-color', column);
                input.type = 'color';
                input.value = text || '#000000';
                break;
            }

            var row = LiveCodeDialog._element('div', 'oxt-dialog-buttons', dialog);
            var elements = [];
            var close = function(index) {
                if (!state.open) {
                    return;
                }
                state.button = index;
                if (input && index >= 0) {
                    state.text = input.value;
                }
                if (state.detached) {
                    // nothing waits for it
                    LiveCodeDialog.release(id);
                    return;
                }
                LiveCodeDialog._close(id);
                LiveCodeAsync.resume();
            };
            buttons.forEach(function(label, index) {
                var button = LiveCodeDialog._element('button', 'oxt-dialog-button', row);
                button.type = 'button';
                button.textContent = label;
                if (index == buttons.length - 1) {
                    button.className += ' oxt-dialog-default';
                }
                button.addEventListener('click', function(e) {
                    e.stopPropagation();
                    if (onChoose && index == chooseButton) {
                        // What the browser does only in a click: open its
                        // file picker (the dialog closes when the files
                        // have been read), or a tab
                        onChoose();
                        if (kind == LiveCodeDialog.kChoose) {
                            return;
                        }
                    }
                    close(index);
                });
                elements.push(button);
            });

            // Return clicks the default button (the last one), and Escape
            // the one named Cancel, as on the desktop
            dialog.addEventListener('keydown', function(e) {
                e.stopPropagation();
                if (e.key == 'Enter' && !e.isComposing) {
                    e.preventDefault();
                    if (elements.length > 0) {
                        elements[elements.length - 1].click();
                    }
                } else if (e.key == 'Escape') {
                    e.preventDefault();
                    for (var i = 0; i < buttons.length; i++) {
                        if (buttons[i].toLowerCase() == 'cancel') {
                            elements[i].click();
                            return;
                        }
                    }
                }
            });
            // Keys and clicks stay in the dialog
            ['keyup', 'keypress', 'mousedown', 'mouseup', 'click', 'contextmenu'].forEach(function(type) {
                backdrop.addEventListener(type, function(e) {
                    e.stopPropagation();
                });
            });
            // OXT-Beyond: a Return pressed before the dialog opened (the
            // one that ran the handler that opened it, such as a
            // returnInField handler or the Message Box) has its keypress
            // after the dialog has taken the focus, and the browser
            // clicked the focused default button with it, closing the
            // dialog before it was seen. A Return pressed in the dialog
            // has no keypress (its keydown is prevented above).
            backdrop.addEventListener('keypress', function(e) {
                if (e.key == 'Enter') {
                    e.preventDefault();
                }
            });

            document.body.appendChild(backdrop);
            var focus = input && input.type != 'color' ? input : elements[elements.length - 1];
            if (focus) {
                focus.focus({'preventScroll': true});
                if (focus === input) {
                    input.select();
                }
            }
            return id;
        },

        // Shows the prompt of a dialog in <element>. As on the desktop, a
        // prompt that holds "<p>" or a start and end tag pair is htmlText:
        // its text is shown with its bold, italic, underline, strikeout,
        // subscript, superscript and colour, and nothing else of it. It
        // is parsed into an inert document, which runs no script and
        // loads nothing, and only its text is copied out of it.
        _setMessage: function(element, message) {
            if (typeof DOMParser == 'undefined' ||
                !/<p>|<([a-z][a-z0-9]*)\b[^>]*>[\s\S]*<\/\1\s*>/i.test(message)) {
                element.textContent = message;
                return;
            }
            var styles = {'B': 'b', 'STRONG': 'b', 'I': 'i', 'EM': 'i', 'U': 'u',
                          'STRIKE': 's', 'S': 's', 'SUB': 'sub', 'SUP': 'sup'};
            var blocks = {'P': true, 'DIV': true, 'LI': true, 'H1': true, 'H2': true,
                          'H3': true, 'H4': true, 'H5': true, 'H6': true};
            var lines = 0;
            var copy = function(from, to, top) {
                for (var node = from.firstChild; node; node = node.nextSibling) {
                    if (node.nodeType == 3) {
                        // the line breaks between the paragraphs of htmlText
                        if (top && /^\s*$/.test(node.nodeValue)) {
                            continue;
                        }
                        to.appendChild(document.createTextNode(node.nodeValue));
                    } else if (node.nodeType == 1) {
                        var tag = node.tagName;
                        if (tag == 'SCRIPT' || tag == 'STYLE' || tag == 'TITLE') {
                            continue;
                        }
                        if (tag == 'BR') {
                            to.appendChild(document.createTextNode('\n'));
                            continue;
                        }
                        if (blocks[tag] && top) {
                            if (lines++ > 0) {
                                to.appendChild(document.createTextNode('\n'));
                            }
                        }
                        var inner = to;
                        if (styles[tag]) {
                            inner = document.createElement(styles[tag]);
                            to.appendChild(inner);
                        } else if (tag == 'FONT' && node.getAttribute('color')) {
                            inner = document.createElement('span');
                            inner.style.color = node.getAttribute('color');
                            to.appendChild(inner);
                        }
                        copy(node, inner, top && blocks[tag] === undefined && !styles[tag] && tag != 'FONT');
                    }
                }
            };
            var parsed = new DOMParser().parseFromString(message, 'text/html');
            copy(parsed.body, element, true);
        },

        _close: function(id) {
            var state = LiveCodeDialog._dialogs[id];
            if (!state || !state.open) {
                return;
            }
            state.open = false;
            if (state.element && state.element.parentNode) {
                state.element.parentNode.removeChild(state.element);
            }
            state.element = null;
            // Give the keyboard back to what had it (the stacks' hidden
            // input field)
            if (state.focus && state.focus.focus && document.contains(state.focus)) {
                state.focus.focus({'preventScroll': true});
            }
        },

        isOpen: function(id) {
            var state = LiveCodeDialog._dialogs[id];
            return !!(state && state.open);
        },

        button: function(id) {
            var state = LiveCodeDialog._dialogs[id];
            return state ? state.button : -1;
        },

        text: function(id) {
            var state = LiveCodeDialog._dialogs[id];
            return state ? state.text : '';
        },

        release: function(id) {
            LiveCodeDialog._close(id);
            delete LiveCodeDialog._dialogs[id];
        },

        // ----------------------------------------------------------------
        // Files the user picks
        // ----------------------------------------------------------------

        kUploads: '/uploads',

        // The path in the engine's file system of a file that the user
        // picked: <folder>/<name>, with "/" in a name replaced
        _uploadPath: function(relative) {
            var parts = relative.split('/').filter(function(part) {
                return part != '' && part != '.' && part != '..';
            });
            return LiveCodeDialog.kUploads + '/' + parts.join('/');
        },

        // Copies a file that the user gave the page into /uploads, at
        // its path <relative> to the folder that the user gave (or its
        // name): returns a promise of the copy's path
        _storeFile: function(file, relative) {
            return file.arrayBuffer().then(function(buffer) {
                var path = LiveCodeDialog._uploadPath(relative);
                FS.mkdirTree(path.substring(0, path.lastIndexOf('/')));
                FS.writeFile(path, new Uint8Array(buffer));
                if (file.lastModified) {
                    try {
                        FS.utime(path, file.lastModified, file.lastModified);
                    } catch (e) {
                    }
                }
                return path;
            });
        },

        // Copies the files that the user picked into /uploads, then
        // closes the dialog <id> with the button 1 and their paths (one
        // per line), or, for a folder, the folder's path
        _storeFiles: function(id, files, folder) {
            var state = LiveCodeDialog._dialogs[id];
            var list = Array.prototype.slice.call(files);
            Promise.all(list.map(function(file) {
                var relative = folder && file.webkitRelativePath ? file.webkitRelativePath : file.name;
                return LiveCodeDialog._storeFile(file, relative);
            })).then(function(paths) {
                if (!state.open) {
                    return;
                }
                if (folder) {
                    var first = list.length > 0 && list[0].webkitRelativePath ?
                        list[0].webkitRelativePath.split('/')[0] : '';
                    state.text = first ? LiveCodeDialog._uploadPath(first) : '';
                    // an empty folder has no files, and so no name
                    state.button = first ? 1 : -1;
                } else {
                    state.text = paths.join('\n');
                    state.button = paths.length > 0 ? 1 : -1;
                }
                LiveCodeDialog._close(id);
                LiveCodeAsync.resume();
            }, function(error) {
                console.error('could not read the files that were picked: ' + error);
                if (state.open) {
                    state.button = -1;
                    LiveCodeDialog._close(id);
                    LiveCodeAsync.resume();
                }
            });
        },

        // OXT-Beyond: copies the files and folders that the user dropped
        // on a stack into /uploads, as the files that the user picks are.
        // <dropped> has a File for each file, or (where the browser has
        // them) a FileSystemEntry for each file and folder. Returns a
        // promise of the copies' paths, one per line: a folder's path for
        // a folder, whose files are copied into it. What cannot be read is
        // left out.
        storeDropped: function(dropped) {
            var store = function(item) {
                if (!item.isFile && !item.isDirectory) {
                    return LiveCodeDialog._storeFile(item, item.name);
                }
                if (item.isFile) {
                    return new Promise(function(resolve, reject) {
                        item.file(resolve, reject);
                    }).then(function(file) {
                        return LiveCodeDialog._storeFile(file, item.fullPath);
                    });
                }
                // A folder's entries come a batch at a time, until one is
                // empty; the folder is made even if it has none
                var folder = LiveCodeDialog._uploadPath(item.fullPath);
                FS.mkdirTree(folder);
                var reader = item.createReader();
                var stored = [];
                var read = function() {
                    return new Promise(function(resolve, reject) {
                        reader.readEntries(resolve, reject);
                    }).then(function(entries) {
                        if (entries.length == 0) {
                            return Promise.all(stored);
                        }
                        entries.forEach(function(entry) {
                            stored.push(store(entry).catch(function(error) {
                                console.error('could not read ' + entry.fullPath + ': ' + error);
                            }));
                        });
                        return read();
                    });
                };
                return read().then(function() {
                    return folder;
                });
            };
            return Promise.all(dropped.map(function(item) {
                return store(item).catch(function(error) {
                    console.error('could not read ' + (item.fullPath || item.name) + ': ' + error);
                    return null;
                });
            })).then(function(paths) {
                return paths.filter(function(path) {
                    return !!path;
                }).join('\n');
            });
        },

        // Opens the browser's file picker; returns the id of a dialog that
        // stays open until the user has picked (button 1, text: the paths)
        // or cancelled (button -1). The browser opens its picker only in
        // a click: when the page has none to answer (the engine runs a
        // handler that a timer sent), a dialog of the page asks for one.
        pickFiles: function(title, message, multiple, folder, accept, chooseLabel, cancelLabel) {
            var input = document.createElement('input');
            input.type = 'file';
            input.multiple = !!multiple;
            if (folder) {
                input.webkitdirectory = true;
            }
            if (accept) {
                input.accept = accept;
            }
            input.style.display = 'none';
            document.body.appendChild(input);

            var id;
            var settled = false;
            var finish = function() {
                if (input.parentNode) {
                    input.parentNode.removeChild(input);
                }
            };
            var cancel = function() {
                var state = LiveCodeDialog._dialogs[id];
                if (settled || !state || !state.open) {
                    return;
                }
                settled = true;
                finish();
                state.button = -1;
                LiveCodeDialog._close(id);
                LiveCodeAsync.resume();
            };
            input.addEventListener('change', function() {
                if (settled) {
                    return;
                }
                settled = true;
                var files = input.files;
                finish();
                if (!files || files.length == 0) {
                    settled = false;
                    cancel();
                    return;
                }
                // the picker's dialog of the page (if any) shows nothing
                // more while the files are read
                var state = LiveCodeDialog._dialogs[id];
                if (state && state.element) {
                    state.element.style.visibility = 'hidden';
                }
                LiveCodeDialog._storeFiles(id, files, folder);
            });
            // Browsers send "cancel" when the picker closes without a
            // choice (Chrome 113, Firefox 91, Safari 16.4); older ones
            // only give the page its focus back
            input.addEventListener('cancel', cancel);
            var onFocus = function() {
                window.removeEventListener('focus', onFocus);
                setTimeout(function() {
                    if (!settled && (!input.files || input.files.length == 0)) {
                        cancel();
                    }
                }, 1000);
            };
            var openPicker = function() {
                window.addEventListener('focus', onFocus);
                input.click();
            };

            var activation = navigator.userActivation;
            if (activation && activation.isActive) {
                // A click or a key that the engine is still answering
                id = LiveCodeDialog.open(LiveCodeDialog.kChoose, 0, '', '', [], '', null, -1);
                LiveCodeDialog._dialogs[id].element.style.visibility = 'hidden';
                openPicker();
            } else {
                id = LiveCodeDialog.open(LiveCodeDialog.kChoose, 0, title, message,
                                         [cancelLabel, chooseLabel], '', openPicker, 1);
            }
            return id;
        },

        // ----------------------------------------------------------------
        // Files the engine gives the user
        // ----------------------------------------------------------------

        kDownloads: '/downloads',

        _types: {
            'txt': 'text/plain', 'csv': 'text/csv', 'html': 'text/html', 'htm': 'text/html',
            'css': 'text/css', 'js': 'text/javascript', 'json': 'application/json',
            'xml': 'application/xml', 'pdf': 'application/pdf', 'png': 'image/png',
            'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'gif': 'image/gif', 'svg': 'image/svg+xml',
            'webp': 'image/webp', 'bmp': 'image/bmp', 'ico': 'image/x-icon', 'mp3': 'audio/mpeg',
            'wav': 'audio/wav', 'ogg': 'audio/ogg', 'm4a': 'audio/mp4', 'mp4': 'video/mp4',
            'webm': 'video/webm', 'zip': 'application/zip',
        },

        _blobOf: function(path) {
            var data = FS.readFile(path);
            var dot = path.lastIndexOf('.');
            var extension = dot > path.lastIndexOf('/') ? path.substring(dot + 1).toLowerCase() : '';
            return new Blob([data], {'type': LiveCodeDialog._types[extension] || 'application/octet-stream'});
        },

        // The files to give the user when the engine next waits, or null
        _downloads: null,

        // Offers a file of the engine's file system to the user as a
        // download, named as it is, when the engine next waits: a file
        // written again meanwhile (opened again to append, a stack saved
        // twice) goes once, as it is then, and a file deleted meanwhile
        // not at all
        offerDownload: function(path) {
            if (LiveCodeDialog._downloads === null) {
                LiveCodeDialog._downloads = [];
                setTimeout(LiveCodeDialog._giveDownloads, 0);
            }
            if (LiveCodeDialog._downloads.indexOf(path) < 0) {
                LiveCodeDialog._downloads.push(path);
            }
            return true;
        },

        _giveDownloads: function() {
            var paths = LiveCodeDialog._downloads;
            LiveCodeDialog._downloads = null;
            for (var i = 0; i < paths.length; i++) {
                // (FS.stat throws for a file that is not there)
                var stat = null;
                try {
                    stat = FS.stat(paths[i]);
                } catch (e) {
                }
                if (stat && !FS.isDir(stat.mode)) {
                    LiveCodeDialog._download(paths[i]);
                }
            }
        },

        _download: function(path) {
            try {
                var url = URL.createObjectURL(LiveCodeDialog._blobOf(path));
                var link = document.createElement('a');
                link.href = url;
                link.download = path.substring(path.lastIndexOf('/') + 1);
                link.style.display = 'none';
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
                setTimeout(function() {
                    URL.revokeObjectURL(url);
                }, 60000);
                return true;
            } catch (e) {
                console.error('could not offer ' + path + ' as a download: ' + e);
                return false;
            }
        },

        // Opens a file of the engine's file system in a new tab (the
        // browser shows what it can show, and downloads the rest)
        openDocument: function(path) {
            var open = function() {
                var url;
                try {
                    url = URL.createObjectURL(LiveCodeDialog._blobOf(path));
                } catch (e) {
                    return false;
                }
                var opened = window.open(url, '_blank');
                setTimeout(function() {
                    URL.revokeObjectURL(url);
                }, 60000);
                return !!opened;
            };
            return LiveCodeDialog.openWithClick(open, 'Open this file?',
                                                path.substring(path.lastIndexOf('/') + 1)) != 0;
        },

        // Runs open(), which opens a tab or hands a link to an
        // application: the browser lets a page do that only while it
        // answers a click or a key. Without one (a handler that a timer
        // sent), a dialog that nothing waits for asks the user, and its
        // Open button runs open() in its click. Returns 1 if open() ran
        // and succeeded, and 2 if the user is asked.
        openWithClick: function(open, title, message) {
            var activation = navigator.userActivation;
            if ((!activation || activation.isActive) && open()) {
                return 1;
            }
            var id = LiveCodeDialog.open(LiveCodeDialog.kAnswer, 0, title, message,
                                         ['Cancel', 'Open'], '', open, 1);
            LiveCodeDialog._dialogs[id].detached = true;
            return 2;
        },
    },

    MCEmscriptenDialogShowAlert__deps: ['$LiveCodeDialog'],
    MCEmscriptenDialogShowAlert: function(message, message_length) {
        return LiveCodeDialog.showAlert(message, message_length);
    },

    MCEmscriptenDialogShowConfirm__deps: ['$LiveCodeDialog'],
    MCEmscriptenDialogShowConfirm: function(message, message_length) {
        return LiveCodeDialog.showConfirm(message, message_length);
    },

    MCEmscriptenDialogShowPrompt__deps: ['$LiveCodeDialog'],
    MCEmscriptenDialogShowPrompt: function(message_buffer, message_length, default_buffer, default_length, return_buffer, return_length) {
        return LiveCodeDialog.showPrompt(message_buffer, message_length, default_buffer, default_length, return_buffer, return_length);
    },

    // Opens a dialog of the page; <buttons> is the labels, one per line
    MCEmscriptenDialogOpen__deps: ['$LiveCodeDialog', '$LiveCodeUtil'],
    MCEmscriptenDialogOpen: function(kind, type, title, title_length, message, message_length, buttons, buttons_length, text, text_length) {
        var labels = LiveCodeUtil.stringFromUTF16(buttons, buttons_length);
        return LiveCodeDialog.open(kind, type,
                                   LiveCodeUtil.stringFromUTF16(title, title_length),
                                   LiveCodeUtil.stringFromUTF16(message, message_length),
                                   labels == '' ? [] : labels.split('\n'),
                                   LiveCodeUtil.stringFromUTF16(text, text_length),
                                   null, -1);
    },

    // Opens the browser's file picker (see pickFiles)
    MCEmscriptenDialogPickFiles__deps: ['$LiveCodeDialog', '$LiveCodeUtil'],
    MCEmscriptenDialogPickFiles: function(title, title_length, message, message_length, multiple, folder, accept, accept_length, labels, labels_length) {
        var buttons = LiveCodeUtil.stringFromUTF16(labels, labels_length).split('\n');
        return LiveCodeDialog.pickFiles(LiveCodeUtil.stringFromUTF16(title, title_length),
                                        LiveCodeUtil.stringFromUTF16(message, message_length),
                                        multiple, folder,
                                        LiveCodeUtil.stringFromUTF16(accept, accept_length),
                                        buttons[1], buttons[0]);
    },

    MCEmscriptenDialogIsOpen__deps: ['$LiveCodeDialog'],
    MCEmscriptenDialogIsOpen: function(id) {
        return LiveCodeDialog.isOpen(id);
    },

    MCEmscriptenDialogGetButton__deps: ['$LiveCodeDialog'],
    MCEmscriptenDialogGetButton: function(id) {
        return LiveCodeDialog.button(id);
    },

    // The dialog's text, as UTF-16 that the engine frees
    MCEmscriptenDialogGetText__deps: ['$LiveCodeDialog', '$LiveCodeUtil'],
    MCEmscriptenDialogGetText: function(id, r_buffer, r_length) {
        var text = LiveCodeDialog.text(id);
        var buffer = LiveCodeUtil.stringToUTF16(text);
        {{{ makeSetValue('r_buffer', '0', 'buffer', 'i32') }}};
        {{{ makeSetValue('r_length', '0', 'text.length', 'i32') }}};
        return true;
    },

    MCEmscriptenDialogRelease__deps: ['$LiveCodeDialog'],
    MCEmscriptenDialogRelease: function(id) {
        LiveCodeDialog.release(id);
    },

    MCEmscriptenOfferDownload__deps: ['$LiveCodeDialog', '$LiveCodeUtil'],
    MCEmscriptenOfferDownload: function(path, path_length) {
        return LiveCodeDialog.offerDownload(LiveCodeUtil.stringFromUTF16(path, path_length));
    },

    MCEmscriptenOpenDocument__deps: ['$LiveCodeDialog', '$LiveCodeUtil'],
    MCEmscriptenOpenDocument: function(path, path_length) {
        return LiveCodeDialog.openDocument(LiveCodeUtil.stringFromUTF16(path, path_length));
    },
});

/*
 * Local Variables:
 * tab-width: 4
 * indent-tabs-mode: t
 * End:
 */
