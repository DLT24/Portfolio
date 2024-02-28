import os

from cs50 import SQL
from flask import Flask, flash, redirect, render_template, request, session
from flask_session import Session
from werkzeug.security import check_password_hash, generate_password_hash
from datetime import datetime

from helpers import apology, login_required, lookup, usd

# Configure application
app = Flask(__name__)

# Custom filter
app.jinja_env.filters["usd"] = usd

# Configure session to use filesystem (instead of signed cookies)
app.config["SESSION_PERMANENT"] = False
app.config["SESSION_TYPE"] = "filesystem"
Session(app)

# Configure CS50 Library to use SQLite database
db = SQL("sqlite:///finance.db")


@app.after_request
def after_request(response):
    """Ensure responses aren't cached"""
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Expires"] = 0
    response.headers["Pragma"] = "no-cache"
    return response

@app.route("/")
@login_required
def index():
    """Show portfolio of stocks"""
    if request.method == "GET":
        userStocks = db.execute(
                       "SELECT symbol, SUM(shares) AS [totalShares], price, SUM(shares*price)"
                       " AS [totalValue] FROM purchases WHERE user_id = ? GROUP BY symbol ORDER BY symbol ASC", session["user_id"]
        )

        userBalances = db.execute(
            "SELECT SUM(purchases.shares*purchases.price) AS [totalValue], users.cash+(SUM(purchases.shares*purchases.price))"
            " AS [grandTotal] FROM purchases INNER JOIN users ON users.id=purchases.user_id WHERE users.id = ?",
            session["user_id"]
        )

        # Try to round
        # userBalances["grandTotal"] = round(userBalances["grandTotal"], 2)

        return render_template("index.html", userStocks=userStocks, userBalances=userBalances)

@app.route("/buy", methods=["GET", "POST"])
@login_required
def buy():
    """Buy shares of stock"""
    if request.method == "POST":

        # Ensure the user has typed in a symbol
        if not request.form.get("symbol"):
            return apology("please input a symbol")

        # Ensure the user inputs the number of shares
        if not request.form.get("shares"):
            return apology("please input number of shares")

        # Use lookup function to obtain price and symbol from the symbol the user typed
        stockPrice = lookup(request.form.get("symbol"))

        # If there is no value returned, issue apology
        if not stockPrice:
            return apology("please input a valid symbol", 403)

        # Select how much cash the user has
        # Select the entire row from the database
        money = db.execute(
            "SELECT * FROM users WHERE id = ?", session["user_id"]
            )
        # Take the value of cash from row 0, to ensure an integer is returned
        money = money[0]["cash"]

        # Has the user got enough cash to buy the stock?
        shares = int(request.form.get("shares"))
        purchaseOrder = int(stockPrice["price"]) * shares
        if money >= purchaseOrder:
            now = datetime.now()
            # If so, add the purchase to the purchases table. The table was created in SQLite manually.
            db.execute("INSERT INTO purchases (user_id, symbol, shares, price, date, transaction_type) VALUES(?, ?, ?, ?, ?, 'purchase')",
                              session["user_id"], stockPrice["symbol"],
                              shares, stockPrice["price"], now)

            # Update cash in the users table to reflect the purchase -  INCOMPLETE
            remainingBalance = money - purchaseOrder
            db.execute("UPDATE users SET cash = ? WHERE id = ?", remainingBalance, session["user_id"])
        else:
            return apology("sorry, you don't have enough cash to make this purchase!", 403)

        # Redirect user to home page
        return redirect("/")

    else:
        return render_template("buy.html")

@app.route("/history")
@login_required
def history():
    """Show history of transactions"""
    if request.method == "GET":
        userTransactions = db.execute("SELECT * FROM purchases WHERE user_id = ? ORDER BY date ASC", session["user_id"])

        return render_template("history.html", userTransactions=userTransactions)

@app.route("/login", methods=["GET", "POST"])
def login():
    """Log user in"""

    # Forget any user_id
    session.clear()

    # User reached route via POST (as by submitting a form via POST)
    if request.method == "POST":
        # Ensure username was submitted
        if not request.form.get("username"):
            return apology("must provide username", 403)

        # Ensure password was submitted
        elif not request.form.get("password"):
            return apology("must provide password", 403)

        # Query database for username
        # Save the result in a variable called rows, for accessing later
        rows = db.execute(
            "SELECT * FROM users WHERE username = ?", request.form.get("username")
        )

        # Ensure username exists and password is correct
        # If the length of the rows variable is not 1, return apology
        # Or if the password that is taken from the first row of the rows variable is not the correct password, return apology
        if len(rows) != 1 or not check_password_hash(
            rows[0]["hash"], request.form.get("password")
        ):
            return apology("invalid username and/or password", 403)

        # Remember which user has logged in
        session["user_id"] = rows[0]["id"]

        # Redirect user to home page
        return redirect("/")

    # User reached route via GET (as by clicking a link or via redirect)
    else:
        return render_template("login.html")

@app.route("/logout")
def logout():
    """Log user out"""

    # Forget any user_id
    session.clear()

    # Redirect user to login form
    return redirect("/")


@app.route("/quote", methods=["GET", "POST"])
@login_required
def quote():
    """Get stock quote."""

    if request.method == "POST":

    # Ensure the user has typed in a symbol
        if not request.form.get("symbol"):
            return apology("please provide a symbol", 403)

        # Use lookup function to obtain price and symbol from the symbol the user typed in the searchbar
        stockQuote = lookup(request.form.get("symbol"))

        # If there is no value returned, issue apology
        if not stockQuote:
            return apology("unable to obtain stock quote", 403)

        # Otherwise render a new template that shows the symbol and price of the stock
        else:
            return render_template("quoted.html", stockQuote=stockQuote)

    else:
       return render_template("quote.html")

@app.route("/register", methods=["GET", "POST"])
def register():
    """Register user"""

    # If the user sends the data via post method
    if request.method == "POST":

        # Ensure the user has typed in a username
        if not request.form.get("username"):
            return apology("must provide username", 403)

        if not request.form.get("password"):
            return apology("must provide password", 403)

        if not request.form.get("confirmation"):
            return apology("must confirm password", 403)

        # Ensure the passwords match
        if request.form.get("password") != request.form.get("confirmation"):
            return apology("password and confirmation must match", 403)

        # Require that the user password has special symbols
        special_symbol = ['!', '?', '%', '$', '£', '#', '€', '@', '^', '*']
        symbol_present = False
        for char in request.form.get("password"):
            if char in special_symbol:
                symbol_present = True

        if not symbol_present:
            return apology("password must contain special symbols", 403)


        # Generate a hash for the password and store the hash in the SQL DB, along with username
        passwordHash = generate_password_hash(request.form.get("password"))
        db.execute(
            "INSERT INTO users (username, hash) VALUES(?, ?)", request.form.get("username"), passwordHash
        )

        # Remember which user has logged in
        rows = db.execute(
            "SELECT * FROM users WHERE username = ?", request.form.get("username")
        )
        session["user_id"] = rows[0]["id"]

        # Redirect user to home page
        return redirect("/")

    # User reached route via GET (as by clicking a link or via redirect)
    else:
        return render_template("register.html")

@app.route("/sell", methods=["GET", "POST"])
@login_required
def sell():
    """Sell shares of stock"""
    # No need to render an apology if user does not own shares in that stock as the select menu only shows stocks that the user owns shares in.
    if request.method == "POST":
        if not request.form.get("shares"):
            return apology("Please insert the number of shares you wish to sell", 403)

        if not request.form.get("stocks"):
            return apology("Please select a symbol", 403)

        # Ensure the user has enough shares to sell
        currentShares = db.execute("SELECT SUM(shares) as total_shares FROM purchases WHERE user_id = ? AND symbol = ?", session["user_id"], request.form.get("stocks"))
        currentShares = int(currentShares[0]["total_shares"])

        if currentShares < int(request.form.get("shares")):
            return apology("sorry, you dont have enough shares to sell", 403)

        # Get the current price of the stock (cannot rely on purchases table as price may have changed since buying)
        currentPrice = lookup(request.form.get("stocks"))
        currentPrice = currentPrice["price"]
        shareNumber = (int(request.form.get("shares"))) * -1 # Convert to negative


        # Give the new balance after selling
        newBalance = db.execute("SELECT cash FROM users WHERE id = ?", session["user_id"]
        )

        newBalance = newBalance[0]["cash"] # Take only the value and not the key-value pair that is returned from the SQL query
        newBalance = newBalance - (currentPrice * shareNumber) # Minus here because shareNumber is negative

        # Update the users table with the new cash balance
        db.execute("UPDATE users SET cash = ? WHERE id = ?", newBalance, session["user_id"])

        # Update the purchases table after selling
        # First add the transaction itself
        now = datetime.now()
        db.execute("INSERT INTO purchases (user_id, symbol, shares, price, date, transaction_type)"
                   "VALUES(?, ?, ?, ?, ?, 'sold')", session["user_id"], request.form.get("stocks"),
                   shareNumber, currentPrice, now
                   )

        return redirect("/")

    else:
        stocks = db.execute(
                       "SELECT DISTINCT symbol FROM purchases WHERE user_id = ? GROUP BY symbol ORDER BY symbol ASC", session["user_id"]
        )

    return render_template("sell.html", stocks=stocks)
