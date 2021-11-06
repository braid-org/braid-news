# Login Form
dom.LOGIN = (c) ->
    DIV
        width: "min(400px, 75%)"
        display: "grid"
        # Maybe use flex instead here?
        marginLeft: "auto"
        marginRight: "auto"
        grid: '"error error" auto
               "name name" 40px
               "pw pw" 40px
               "email email" 40px
               "register login" 40px
                / auto auto'
        gap: "10px"
        DIV
            gridArea: "error"
            display: "none" unless c.error
            c.error
        INPUT
            id: "login-name"
            placeholder: "Username"
            gridArea: "name"
        INPUT
            id: "login-pw"
            placeholder: "Password"
            gridArea: "pw"
        INPUT
            id: "login-email"
            placeholder: "Email, if registering"
            gridArea: "email"

        BUTTON
            gridArea: "register"
            onClick: (e) ->
                name = document.getElementById("login-name").value
                pw = document.getElementById("login-pw").value
                em = document.getElementById("login-email").value
                c.create_account =
                    name: name
                    pass: pw
                    email: em
                save c
            "Register"
        BUTTON
            gridArea: "login"
            onClick: (e) ->
                name = document.getElementById("login-name").value
                pw = document.getElementById("login-pw").value
                c.login_as =
                    name: name
                    pass: pw
                save c
            "Login"