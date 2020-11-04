# Copyright (c) 2007-2020 Andy Maleh
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

include Glimmer

shell { |shell_proxy|
  text 'Hello, Menu Bar!'
  grid_layout
  label(:center) {
    font height: 16
    text 'Check Out The File Menu and History Menu in The Menu Bar Above!'
  }
  menu_bar {
    menu {
      text '&File'
      menu_item {
        text 'E&xit'
        on_widget_selected {
          exit(0)
        }
      }
      menu_item(0) {
        text '&New'
        on_widget_selected {
          message_box(shell_proxy) {
            text 'New File'
            message 'New File Contents'
          }.open
        }
      }
      menu(1) {
        text '&Options'
        menu_item(:radio) {
          text 'Option 1'
        }
        menu_item(:separator)
        menu_item(:check) {
          text 'Option 3'
        }
      }
    }
    menu {
      text '&History'
      menu {
        text '&Recent'
        menu_item {
          text 'File 1'
          on_widget_selected {
            message_box(shell_proxy) {
              text 'File 1'
              message 'File 1 Contents'
            }.open
          }
        }
        menu_item {
          text 'File 2'
          on_widget_selected {
            message_box(shell_proxy) {
              text 'File 2'
              message 'File 2 Contents'
            }.open
          }
        }
      }
    }
  }
}.open
