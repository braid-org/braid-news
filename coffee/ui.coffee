# TODO: These should be arguments for the relevant elements
# TODO: Should UI elements fetch global state or take arguments?
body_width = 800
margin_left = 40
post_width = 575

# The layout for a single post, including slidergram and such
dom.RENDER_POST = ->
    post = @props.post
    # Subscribe to the post
    if post.key then fetch post
    unless post.user?
        # The post has actually just been deleted.
        return

    author = fetch post.user

    c = fetch '/current_user'

    # Compute the pretty-url
    url = if post.url.startsWith "javascript:" then "" else post.url

    pretty_url = url
    functional_url = url
    unless url.startsWith("https://") or url.startsWith("http://")
        functional_url = "https://" + functional_url
    try
        the_url = new URL functional_url
        the_url.protocol = "https://"
        functional_url = the_url.toString()
        pretty_url = the_url.host
    catch e 
        functional_url = ""
    
    #time_string = ""
    #delta = Date.now() / 1000 - post.time
    #if delta > 60 * 60 * 24
    #    time_string = "#{Math.floor(delta / (60 * 60 * 24))} days"
    #else if delta > 60 * 60
    #    time_string = "#{Math.floor(delta / (60 * 60))} hours"
    #else if delta > 60
    #    time_string = "#{Math.floor(delta / 60)} minutes"
    #else
    #    time_string = "#{Math.floor(delta)} seconds"
    time_string = prettyDate(post.time * 1000)


    user_clickable = c.logged_in and (c.user.key != author.key)

    DIV
        marginTop: "10px"
        marginBottom: "10px"
        display: "grid"
        grid: "\"icon title slider del\" auto
               \"icon domain_time slider del\" 16px
                / #{margin_left}px #{post_width + 10}px 1fr #{margin_left}px"
        alignItems: "center"

        AVATAR_WITH_SLIDER
            key: "avatar"
            user: author
            clickable: user_clickable
            width: margin_left - 10
            height: margin_left - 10
            style:
                gridArea: "icon"
                zIndex: 5
                alignSelf: "center"

        A
            key: "title"
            className: "post-title"
            gridArea: "title"
            fontSize: "18px"
            paddingRight: "10px"
            lineHeight: "#{margin_left - 10}px"
            justifySelf: "stretch"
            textDecoration: "none"
            href: if functional_url.length then functional_url
            "#{post.title}"

        SPAN
            key: "url_time"
            gridArea: "domain_time"
            fontSize: "12px"
            color: "#999"
            whiteSpace: "nowrap"
            overflowX: "hidden"
            textOverflow: "ellipsis"
            "#{pretty_url} · #{time_string}"
        
        DIV
            key: "post-votes-slider"
            gridArea: "slider"
            alignSelf: "start"
            height: margin_left - 10
            SLIDERGRAM
                sldr: "/votes_on#{post.key}"
                width: body_width - 2*margin_left - post_width - 10
                height: margin_left - 5
                max_avatar_radius: (margin_left - 5) / 2
                read_only: !c.logged_in
                vote_key: "user"

        if c.logged_in and c.user.key == author.key then SPAN
            key: "delete-btn"
            color: "#999"
            className: "material-icons md-dark"
            fontSize: "24px"
            cursor: "pointer"
            textAlign: "end"
            gridArea: "del"
            onClick: (e) ->
                delete_post(post)
            "delete"

dom.HEADER = ->
    # view state contains information about whatever the current view is
    # In the future, we'll create a type of state that can be "viewed" (such as a project, user, or tag), and the HEADER will recieve that as a paremeter...
    v = fetch "view"
    c = fetch "/current_user"

    feed_name = "Braid"
    if v.selected or c.logged_in
        viewer = fetch (v.selected || c.user)
        feed_name = "#{viewer.name}'s"

   
    DIV
        key: "header"
        position: "relative"
        zIndex: 10
        DIV
            key: "actual-header"
            ref: "header"
            display: "flex"
            flexDirection: "row"
            alignItems: "center"
            background: "#def"
            padding: "10px 50px"
            color: "#444"
            zIndex: 5

            SPAN
                key: "title"
                fontSize: 36
                flexGrow: 1
                "#{feed_name} feed"

            SPAN
                key: "home"
                margin: 10
                "Home"

            SPAN
                key: "feeds"
                ref: "feeds"
                margin: 10
                cursor: "pointer"
                onClick: () => 
                    bbox_feeds = @refs.feeds.getDOMNode().getBoundingClientRect()
                    bbox_header = @refs.header.getDOMNode().getBoundingClientRect()
                    @local.offset = bbox_header.right - bbox_feeds.right
                    @local.modal = if @local.modal == "feeds" then false else "feeds"
                    save @local
                # "Preload" the list of feeds:
                # Otherwise the popup will be blank while waiting for the server...
                # Is there a better way to guess when to preload the feeds?
                onMouseEnter: () -> fetch "/feeds"
                "Feeds"

            SPAN
                key: "post"
                margin: 10
                cursor: "pointer"
                onClick: () => 
                    @local.modal = if @local.modal == "post" then false else "post"
                    @local.offset = 0
                    save @local
                "Post"

            if c.logged_in
                SPAN
                    key: "user"
                    cursor: "pointer"
                    display: "contents"
                    onClick: () => 
                        @local.modal = if @local.modal == "settings" then false else "settings"
                        @local.offset = 0
                        save @local

                    SPAN
                        key: "name"
                        marginLeft: 14
                        marginRight: 4
                        c.user.name
                    AVATAR
                        user: c.user
                        hide_tooltip: true
                        style:
                            borderRadius: "50%"
                            width: 45
                            height: 45
            else
                SPAN
                    key: "user"
                    margin: 10
                    cursor: "pointer"
                    onClick: () => 
                        @local.modal = if @local.modal == "login" then false else "login"
                        @local.offset = 0
                        save @local
                    "Login"



        DIV
            key: "dropdown"
            display: "none" unless @local.modal 
            position: "absolute"
            zIndex: 6
            right: @local.offset ? 0
            marginTop: 10
            padding: 10
            background: "white"
            boxShadow: "rgba(0, 0, 0, 0.15) 0px 1px 5px 1px"

            close = () =>
                @local.modal = false
                save @local
            
            switch @local.modal
                when "post" then SUBMIT_POST(close: close)
                when "settings" then SETTINGS(close: close)
                when "login" then LOGIN(close: close)
                when "feeds" then FEEDS()





dom.SUBMIT_POST = ->

    @local.typed ?= false

    c = fetch "/current_user"
    unless c.logged_in
        return

    form_submit = =>
        title = @refs["post-title"].getDOMNode()
        link = @refs["post-url"].getDOMNode()
        if title.value.length > 1 and link.value.length > 1
            make_post title.value, link.value, c.user.key
            title.value = ""
            link.value = ""

        @props.close?()

    DIV
        key: "submit-container"
        display: "grid"
        grid: "\"icon title slider\" auto
               \"icon domain_time slider\" 16px
                / #{margin_left}px #{post_width + 10}px 1fr "
        alignItems: "center"

        AVATAR
            key: "avatar"
            user: c.user
            hide_tooltip: true
            gridArea: "icon"
            style:
                width: margin_left - 10
                height: margin_left - 10
                borderRadius: "50%"
                alignSelf: "center"
                opacity: 0.5

        INPUT
            key: "title"
            ref: "post-title"
            className: "post-title"
            gridArea: "title"
            fontSize: "18px"
            paddingRight: "10px"
            marginBottom: "2px"
            border: "none"
            lineHeight: "#{margin_left - 10}px"
            justifySelf: "stretch"
            placeholder: "Say something..."
            onKeyDown: (e) =>
                if e.keyCode == 13
                    form_submit()
                else if e.keyCode == 9
                    e.preventDefault()
                    @refs["post-url"].getDOMNode().focus()


        INPUT
            key: "url"
            ref: "post-url"
            gridArea: "domain_time"
            fontSize: "12px"
            color: "#999"
            whiteSpace: "nowrap"
            placeholder: "https://..."
            border: "none"
            onKeyDown: (e) =>
                if e.keyCode == 13
                    form_submit()
                else if e.keyCode == 9
                    e.preventDefault()
        
        SPAN
            key: "submit-btn"
            gridArea: "slider"
            alignSelf: "start"
            height: margin_left - 10
            textAlign: "center"
            alignSelf: "center"
            className: "material-icons md-dark"
            fontSize: "24px"
            onClick: form_submit
            cursor: "pointer"
            "post_add"



# Login Form
dom.LOGIN = ->
    c = fetch "/current_user"
    button_style =
        justifySelf: "center"
        minWidth: "80%"
        paddingLeft: "5px"
        paddingRight: "5px"

    DIV
        width: 200
        paddingRight: "10px"
        display: "grid"
        # Maybe use flex instead here?
        grid: '"error error" auto
               "name name" 32px
               "pw pw" 32px
               "email email" 32px
               "register login" 24px
                / auto auto'
        gap: "6px"
        DIV
            gridArea: "error"
            display: "none" unless c.error
            fontSize: "12px"
            color: "red"
            c.error
        INPUT
            id: "login-name"
            ref: "login-name"
            placeholder: "Username"
            gridArea: "name"
        INPUT
            id: "login-pw"
            ref: "login-pw"
            placeholder: "Password"
            gridArea: "pw"
            type: "password"
        INPUT
            id: "login-email"
            ref: "login-email"
            placeholder: "Email"
            gridArea: "email"
            type: "email"

        BUTTON {
            gridArea: "register"
            button_style...

            onClick: (e) =>
                name = @refs["login-name"].getDOMNode().value
                pw = @refs["login-pw"].getDOMNode().value
                em = @refs["login-email"].getDOMNode().value
                c.create_account =
                    name: name
                    pass: pw
                    email: em
                save c

                # I want to also log in here. But doing it naively will cause a race condition,
                # Maybe we can set a one-time to_save handler?
                #c.login_as =
                #    name: name
                #    pass: pw
                #save c

                @props.close?()
            },
            "Register"

        BUTTON {
            gridArea: "login"
            button_style...
            onClick: (e) =>
                name = @refs["login-name"].getDOMNode().value
                pw = @refs["login-pw"].getDOMNode().value
                c.login_as =
                    name: name
                    pass: pw
                save c

                @props.close?()

            },
            "Login"

dom.SETTINGS = ->
    c = fetch "/current_user"
    unless c.logged_in
        return
    DIV
        width: "250"
        display: "grid"
        # Maybe use flex instead here?
        alignContent: "center"
        grid: '"nametag namefield namefield" 32px
               "emailtag emailfield emailfield" 32px
               "pictag picfield picfield" 32px
               "filtertag filterfield filterfield" 32px
               ". cancel save" 24px
                / auto auto auto'
        gap: "5px"
        
        DIV
            gridArea: "nametag"
            color: "#333"
            fontSize: "12px"
            "Name"
        INPUT
            gridArea: "namefield"
            ref: "name"
            value: c.user.name
            id: "name-change"

        DIV
            gridArea: "emailtag"
            color: "#333"
            fontSize: "12px"
            "Email"
        INPUT
            gridArea: "emailfield"
            ref: "email"
            value: c.user.email
            id: "email-change"
            type: "email"

        DIV
            gridArea: "pictag"
            color: "#333"
            fontSize: "12px"
            "Avatar URL"
        INPUT
            gridArea: "picfield"
            ref: "pic"
            value: c.user.pic
            placeholder: "http://..."
            id: "pic-change"
        DIV
            gridArea: "filtertag"
            color: "#333"
            fontSize: "12px"
            "Min post score"
        INPUT
            gridArea: "filterfield"
            ref: "filter"
            value: c.user.filter
            placeholder: -0.2
            id: "filter-change"
            type: "number"
            step: 0.1


        BUTTON
            gridArea: "cancel"
            onClick: (e) => @props.close?()
            "Cancel"
        BUTTON
            gridArea: "save"
            onClick: (e) =>
                
                name = @refs.name.getDOMNode().value
                email = @refs.email.getDOMNode().value
                pic = @refs.pic.getDOMNode().value ? ""
                filter = @refs.filter.getDOMNode().value ? -0.2

                c.user.name = name
                c.user.email = email
                c.user.pic = pic
                c.user.filter = Number.parseFloat(filter)

                save c.user
                
                # Close the settings box
                @props.close?()
            "Save"

# TODO: Figure out how to "prefetch" things?
dom.FEEDS = ->
    c = fetch "/current_user"
    v = fetch "view"
    feeds = (fetch "/feeds").all
    weights = fetch "/weights/#{unslash (c.user?.key ? 'user/default')}"
    # sort feeds to put the selected one first...
    feeds = feeds.sort((a, b) => (weights[a._key] ? 0) - (weights[b._key] ? 0))
                 .filter (a) => a._key != c.user?.key
        #switch
        #    when a.key == v.selected then -10
        #    when b.key == v.selected then 10
        #    else (weights[a.key] ? 0) - (weights[b.key] ? 0)
    DIV
        key: "feeds-scroll-list"
        ref: "feeds"
        maxHeight: 200
        overflowY: "auto"
        paddingLeft: 5
        paddingRight: 20
        display: "grid"
        gridTemplateColumns: "24px auto 1fr"
        gridTemplateRows: "24px"
        gridAutoRows: "24px"
        gridGap: "10px 4px"
        alignItems: "center"

        for feed in feeds
            FEEDS_ITEM
                feed: feed


dom.FEEDS_ITEM = ->
    feed = @props.feed
    v = fetch "view"
    selected = v.selected == feed._key
    type = "user"

    DIV
        key: "feed-#{type}-#{feed._key}"
        display: "contents"
        cursor: "pointer"
        color: if selected then "#179"
        onClick: () ->
            v.selected = if selected then false else feed._key
            save v

        # TODO: How is an avatar rendered for something that isn't a user?
        AVATAR
            user: feed._key
            key: "icon"
            hide_tooltip: true
            style:
                width: 24
                height: 24
                borderRadius: "50%"

        SPAN
            key: "type"
            fontWeight: "bold"
            textTransform: "capitalize"
            "#{type}:"

        SPAN
            key: "name"
            feed.name
