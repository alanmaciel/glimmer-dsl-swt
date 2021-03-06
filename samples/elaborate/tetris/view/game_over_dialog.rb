# Copyright (c) 2007-2021 Andy Maleh
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

require_relative 'tetris_menu_bar'

class Tetris
  module View
    class GameOverDialog
      include Glimmer::UI::CustomShell
  
      options :parent_shell, :game
      
      after_body {
        observe(game, :game_over) do |game_over|
          hide if !game_over
        end
      }
      
      body {
        dialog(parent_shell) {
          row_layout {
            type :vertical
            center true
          }
          text 'Tetris'
          
          tetris_menu_bar(game: game)
          
          label(:center) {
            text 'Game Over!'
            font name: 'Menlo', height: 30, style: :bold
          }
          label # filler
          button {
            text 'Play Again?'
            
            on_widget_selected {
              hide
              game.restart!
            }
          }
          
          on_shell_activated {
            display.beep
          }
        }
      }
    end
  end
end
