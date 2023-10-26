#!/usr/bin/env python3
from stockfish import *
from inputimeout import inputimeout
import time
from datetime import datetime
import random

thinking_time = 1000

game = Stockfish(path="./stockfish", depth=15, parameters={"Threads": 1, "Minimum Thinking Time": thinking_time, "UCI_Chess960": True})

def create_random_position():
    pos = "/pppppppp/8/8/8/8/PPPPPPPP/"
    rank8 = ["r","r","b","q","k","b","n","n"]

    while rank8.index("k") < [i for i, n in enumerate(rank8) if n == "r"][0] or rank8.index("k") > [i for i, n in enumerate(rank8) if n == "r"][1] or [i for i, n in enumerate(rank8) if n == "b"][0] % 2 == [i for i, n in enumerate(rank8) if n == "b"][1] % 2:
        random.seed(datetime.now().microsecond)
        random.shuffle(rank8)

    rank1 = [c.upper() for c in rank8]
    pos = "".join(rank8) + pos + "".join(rank1) + " w KQkq - 0 1"
    game.set_fen_position(pos)

def player_won():
    with open("flag.txt") as file:
        flag = file.read()
    print(flag)
    exit()

def get_fast_player_move():
    try:
        time_over = inputimeout(prompt='Your move: ', timeout=5)
    except Exception:
        time_over = 'Too slow, you lost!'
        print(time_over)
        exit()
    return time_over

def check_game_status():
    evaluation = game.get_evaluation()
    turn = game.get_fen_position().split(" ")[1]
    if evaluation["type"] == "mate" and evaluation["value"] == 0 and turn == "w":
        print("Wow, you beat me!")
        player_won()
    elif evaluation["type"] == "mate" and evaluation["value"] == 0 and turn == "b":
        print("Hah, I won again")
        exit()
    if evaluation["type"] == "draw":
        print("It's a draw!")
        print("Impressive, but I am still undefeated.")
        exit()

if __name__ == "__main__":
    create_random_position()
    print("Welcome to fischer chess.\nYou get 5 seconds per move. Good luck")
    print(game.get_board_visual())
    print("Heres the position for this game, Ill give you a few seconds to look at it before we start.")
    time.sleep(3)
    while True:
        server_move = game.get_best_move_time(thinking_time)
        game.make_moves_from_current_position([server_move])
        check_game_status()
        print(game.get_board_visual())
        print(f"My move: {server_move}")
        player_move = get_fast_player_move()
        if type(player_move) != str or len([player_move]) != 1:
            print("Illegal input")
            exit()
        try:
            game.make_moves_from_current_position([player_move])
            check_game_status()
        except:
            print("Couldn't comprehend that")
            exit()
