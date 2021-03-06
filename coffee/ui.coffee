# TODO: These should be arguments for the relevant elements
# TODO: Should UI elements fetch global state or take arguments?

### === POST FEED === ###
dom.POSTS = ->
    c = fetch "/current_user"
    v = fetch "view"
    posts = (fetch "/posts#{stringify_kson tag: v.tag}").arr ? []

    # User who's viewing the posts
    username = v.user_key ? c?.user?.key ? "/user/default"
    min_weight = (if c.logged_in then (fetch c.user)?.filter) ? -0.2
    # KSON blob to be passed to the scores state
    score_kson = stringify_kson tag: v.tag, user: username

    two_weeks_ago = (Date.now() / 1000) - 60 * 60 * 24 * 14
    # Recent posts with a positive score, sorted by time
    posts_recent = posts.filter (p) ->
            (p.time > two_weeks_ago) and 
            (fetch("score#{p.key}#{score_kson}").value ? 0) > 0.1 # TODO: Tune this
        .sort (a, b) -> b.time - a.time

    # Older posts, sorted by score
    posts_old = posts.filter (p) -> 
            (p.time <= two_weeks_ago) and 
            # Cut the list off at some point. TODO: Paging
            (fetch("score#{p.key}#{score_kson}").value ? 0) > min_weight
        .sort (a, b) -> (fetch("score#{b.key}#{score_kson}").value ? 0) - (fetch("score#{a.key}#{score_kson}").value ? 0)

    
    DIV
        key: "posts"
        # Recent posts are displayed at the top
        posts_recent.map (post) ->
            POST
                post: post.key
                key: unslash post.key

        # If there were no recent posts, don't show the time separator
        if posts_recent.length
            DIV
                key: "sort-separator"
                display: "flex"
                flexDirection: "row"
                justifyContent: "stretch"
                alignItems: "center"

                # Blue line on the left
                DIV
                    key: "dummy1"
                    flexGrow: 1
                    height: 1.5
                    background: "#36a"
                    borderRadius: 1

                SPAN
                    key: "text"
                    color: "#36a"
                    margin: "0px 1ch"
                    "Two weeks ago"

                # Blue line on the right
                DIV
                    key: "dummy2"
                    flexGrow: 1
                    height: 1.5
                    background: "#36a"
                    borderRadius: 1

        # Older posts are displayed below the separator
        posts_old.map (post) ->
            POST
                post: post.key
                key: unslash post.key

# The layout for a single post, including slidergram and such
dom.POST = ->
    post = @props.post
    # Subscribe to the post
    if post?.key or typeof post == "string" then post = fetch post
    unless post.user_key?
        # The post has actually just been deleted.
        return

    author = fetch post.user_key

    c = fetch '/current_user'
    v = fetch "view"

    # Compute the pretty version of the url
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
    
    time_string = prettyDate(post.time * 1000)
    user_clickable = c.logged_in and (c.user.key != author.key)

    DIV
        margin: "5px 0"
        padding: "5px 10px"
        boxShadow: if @local.expanded then "rgba(0, 0, 0, 0.15) 0px 1px 5px 1px"
        position: "relative"
        zIndex: if @local.expanded then 5

        DIV
            key: "post-main"
            display: "grid"
            grid: "\"icon title slider more\" auto
                   \"icon domain_time slider more\" 16px
                   \".  delete . .\" auto
                    / 1fr #{inner_width - slider_width}px #{slider_width}px 1fr"
            width: outer_width
            alignItems: "center"

            AVATAR_WITH_SLIDER
                key: "avatar"
                user: author
                clickable: user_clickable
                width: slider_height - 10
                height: slider_height - 10
                style:
                    gridArea: "icon"
                    alignSelf: "center"
                    justifySelf: "center"

            A
                key: "title"
                className: "post-title"
                gridArea: "title"
                fontSize: "18px"
                paddingRight: "10px"
                lineHeight: 1.3
                justifySelf: "stretch"
                textDecoration: "none"
                href: if functional_url.length then functional_url
                "#{post.title}"

            SPAN
                key: "delete-btn"
                gridArea: "delete"
                color: "#999"
                fontSize: "12px"
                cursor: "pointer"
                display: unless c?.user?.key == post?.user_key and @local.expanded then "none"
                onClick: () -> del post.key
                "Delete post"

            SPAN
                key: "url_time"
                gridArea: "domain_time"
                fontSize: "12px"
                color: "#999"
                whiteSpace: "nowrap"
                overflowX: "hidden"
                textOverflow: "ellipsis"
                "#{if @local.expanded then url else pretty_url} ?? #{time_string}"
           
            DIV
                key: "post-votes-slider"
                gridArea: "slider"
                alignSelf: "start"
                height: slider_height + 5
                # If we're viewing with respect to a tag, apply the tag to the slidergram
                if v.tag
                    SLIDERGRAM_WITH_TAG
                        key: "slidergram"
                        post: post
                        tag: unslash v.tag
                        width: slider_width
                        height: slider_height
                        max_avatar_radius: slider_height / 2
                        read_only: !c.logged_in
                else
                    SLIDERGRAM
                        key: "slidergram"
                        sldr: "/votes/#{unslash post.key}(untagged)"
                        width: slider_width
                        height: slider_height
                        max_avatar_radius: slider_height / 2
                        read_only: !c.logged_in
                        vote_key: "user_key"
                        onsave: (vote) =>
                            vote.key = "#{c.user.key}/vote/#{unslash post.key}"
                            vote.target_key = post.key
                            save vote

            SPAN
                key: "more"
                gridArea: "more"
                color: "#999"
                className: "material-icons-outlined md-dark"
                fontSize: "24px"
                cursor: "pointer"
                textAlign: "center"
                display: if @props.no_expand then "none"
                onClick: () => 
                    @local.expanded = !@local.expanded
                    save @local
                if @local.expanded then "expand_less" else "expand_more"


        if @local.expanded and !@props.no_expand
            POST_DETAILS
                key: "details-dropdown"
                post: post


# The expanded part underneath a post.
dom.POST_DETAILS = ->

    DIV
        width: inner_width
        margin: "5px auto"
        DIV
            key: "lr-panels-container"
            display: "flex"
            flexDirection: "row"
            justifyContent: "space-between"
            alignContent: "stretch"

            COMMENTS
                key: "comments"
                post_key: @props.post?.key ? @props.post
                style:
                    flexGrow: 1
                    marginRight: 15

            TAGS
                key: "tags"
                post: @props.post
        DIV
            key: "permalink"
            textAlign: "center"
            cursor: "pointer"
            onClick: () => load_path @props.post?.key ? @props.post
            "Full comments and tags"

dom.FULL_PAGE_POST = ->

    DIV
        display: "flex"
        flexDirection: "column"
        alignItems: "center"
        marginTop: 15
        POST
            key: "the-post"
            post: @props.post
            can_expand: no
        DIV
            key: "lr-panels-container"
            display: "flex"
            flexGrow: 1
            flexDirection: "row"
            justifyContent: "space-between"
            alignContent: "stretch"
            width: "80vw"
            minWidth: outer_width
            maxWidth: 1150
            marginTop: 15

            COMMENTS
                key: "comments"
                post_key: @props.post
                max_depth: 15
                max_comments: 1000
                style: flexGrow: 1

            TAGS
                key: "tags"
                post: @props.post
                max_tags: 1000
                style: marginLeft: 30

dom.TAGS = ->

    c = fetch "/current_user"
    post = fetch @props.post
    # Cache this?
    potential_tags = (fetch "/tags").arr.filter (f) -> f not in (post.tags || [])
    max_suggestions = @props.max_suggestions ? 4
    # Setup default values in @local
    # These values are used for the tag search box
    @local.selected_idx ?= -1
    @local.tagsearch ?= []
    @local.typed ?= ""
    @local.addtagvisible ?= false
    save @local

    tags_shown = (post.tags || [])
    max_tags = @props.max_tags ? 5
    too_many_tags = false
    if tags_shown.length > max_tags
        tags_shown = tags_shown[...max_tags]
        # Save some state indicating that the post display is too long
        too_many_tags = true
        

    DIV
        display: "flex"
        flexDirection: "column"
        alignContent: "stretch"
        style: @props.style

        # The tags that are actually on the post, plus their sliders
        DIV
            key: "tags-grid"
            display: "grid"
            gridTemplateColumns: "minmax(5em, auto) #{slider_width}px"
            gridColumnGap: 10
            gridAutoRows: slider_height + 5
            alignItems: "center"

            for tag in tags_shown
                DIV
                    key: "tag-#{tag}"
                    display: "contents"
                    SPAN
                        key: "tag-text"
                        fontSize: 16
                        lineHeight: 1.1
                        textTransform: "capitalize"
                        color: "#444"
                        "#{tag}:"

                    SLIDERGRAM_WITH_TAG
                        key: "tag-slidergram"
                        post: post
                        tag: tag
                        width: slider_width
                        height: slider_height
                        max_avatar_radius: slider_height / 2
                        read_only: !c.logged_in
        if too_many_tags
            SPAN
                key: "too-many-tags"
                marginTop: 8
                alignSelf: "center"
                color: "#999"
                fontSize: 14
                "Some tags were hidden."
        else
            # Add-tag searchbox
            SPAN
                key: "add-tag"
                marginTop: 8
                overflowY: "visible"
                height: 24
                alignSelf: "center"

                confirm_add = () =>
                    box = @refs.addlabel.getDOMNode()
                    if @local.addtagvisible and box.value.length
                        post.tags ||= []
                        new_tag = box.value.toString().toLowerCase()
                        # Disable adding certain tags.
                        # In the future, we should make this check serverside so it can't be bypassed.
                        if new_tag.indexOf("/") == -1 and ["users", "about"].indexOf(new_tag) ==  -1
                            post.tags.push new_tag
                        box.value = ""
                        save post
                    
                    @local.addtagvisible = !@local.addtagvisible
                    @local.tagsearch = []
                    save @local

                DIV
                    key: "input-and-suggestions"
                    display: "inline-flex"
                    flexDirection: "row"
                    alignItems: "center"
                    # So that the dropdown suggestions can align with the search bar
                    marginLeft: 4

                    INPUT
                        key: "textbox"
                        ref: "addlabel"
                        placeholder: "Relevant tag..."
                        display: unless @local.addtagvisible then "none"
                        width: slider_width
                        border: "none"
                        # Handle arrow keys, enter, etc
                        onKeyDown: (e) =>
                            switch e.keyCode
                                # Enter
                                when 13
                                    e.preventDefault()
                                    confirm_add()
                                # Up/down, tab
                                when 38, 40, 9
                                    e.preventDefault()
                                    v = @refs.addlabel.getDOMNode()
                                    # Up arrow is 38, down arrow is 40, tab is 9
                                    di = switch e.keyCode
                                        when 38 then -1
                                        when 40 then 1
                                        when 9 then 1
                                    # Increment or decrement the index
                                    @local.selected_idx += di
                                    switch @local.selected_idx
                                        # If we scrolled past the last one, or up from the 1st/0th, unselect
                                        when @local.tagsearch.length, -1, -2
                                            @local.selected_idx = -1
                                            v.value = @local.typed
                                        else
                                            # Otherwise, set the textbox value to the right name
                                            v.value = @local.tagsearch[@local.selected_idx]
                                # Escape
                                when 27
                                    @local.tagsearch = []
                            save @local
                        # Handle actual text entry
                        onInput: (e) =>
                            v = @refs.addlabel.getDOMNode().value.toString().toLowerCase()
                            @local.typed = v
                            # Get the tags that start with the query
                            # In the future, could do a fuzzy search
                            @local.tagsearch = potential_tags.filter((t) => t.startsWith v)
                                                             .slice 0, max_suggestions
                            @local.selected_idx = -1
                            unless v.length then @local.tagsearch = []
                            save @local

                            
                    SPAN
                        key: "textbox-replacement"
                        display: if @local.addtagvisible then "none"
                        color: "#999"
                        marginLeft: 40
                        cursor: "pointer"
                        onClick: () =>
                            @local.addtagvisible = !@local.addtagvisible
                            @local.tagsearch = []
                            save @local

                        "Add Tag"


                    SPAN
                        key: "addbutton"
                        ref: "addbutton"
                        color: "#999"
                        className: "material-icons-outlined md-dark"
                        fontSize: "24px"
                        cursor: "pointer"
                        marginLeft: 6
                        onClick: confirm_add

                        # Have an X instead when the field is empty?
                        if @local.addtagvisible then "done" else "add_box"

                DIV
                    key: "results-overflow"
                    marginTop: 5
                    overflowY: "visible"
                    background: "white"
                    boxShadow: "0 2px 3px rgba(0,0,0,0.2)"
                    # match the input box width, with the symmetrical padding
                    width: slider_width + 4
                    # Using map instead of for ... in prevents scoping issues, and allows access to the index
                    @local.tagsearch.map (suggested, i) =>
                        DIV
                            key: "#{suggested}-res"
                            cursor: "pointer"
                            className: "hover-select"
                            fontSize: 16
                            lineHeight: 1
                            color: "#444"
                            padding: 4
                            background: if i == @local.selected_idx then "#eee"
                            textTransform: "capitalize"
                            onClick: (e) =>
                                # Save text of the selected result in the widget state
                                @refs.addlabel.getDOMNode().value = suggested
                                @local.selected_idx = i
                                save @local

                            suggested

# Comments list
dom.COMMENTS = ->
    c = fetch "/current_user"
    post = @props.post_key

    comments_arr = (fetch "#{post}/comments").arr ? []
    # Arrange comments into a tree
    children = post: []
    comments_arr.forEach (com) ->
        parent = com.parent_key ? "post"
        (children[parent] ?= []).push com.key

    # Flatten tree
    # TODO: Deal with orphans
    # TODO: Sort
    # TODO: Incorporate weight
    # TODO: Rather than increasing depth constantly, make it thready
    flattened = []
    too_many_comments = false
    explore = (key, depth) =>
        # Once we reach this many comments, stop the whole search
        if too_many_comments ||= (flattened.length >= (@props.max_comments ? 10))
            return
        # Add the comment
        flattened.push {key, depth}
        # If there's a cut-off thread, add an etc
        if depth == (@props.max_depth ? 4) and children[key]?.length
            flattened.push { key: "#{key}-etc", depth: depth + 1, etc: true }
        # Otherwise explore
        else
            children[key]?.forEach (c) -> explore c, depth + 1

    children.post?.forEach (c) -> explore c, 0

    DIV
        key: "comments"
        display: "flex"
        flexDirection: "column"
        alignContent: "stretch"
        style: @props.style

        if c.logged_in
            # Post-a-comment
            DIV
                key: "post-comment"
                display: "flex"
                flexDirection: "row"
                alignContent: "stretch"

                AVATAR
                    key: "my-avatar"
                    user: c.user.key
                    hide_tooltip: yes
                    marginRight: "8px"
                    style:
                        borderRadius: "50%"
                        width: 24
                        height: 24
                        flexShrink: 0

                TEXTAREA
                    key: "comment"
                    ref: "comment"
                    marginRight: "5px"
                    rows: 3
                    flexGrow: 1
                    flexShrink: 0
                    resize: "none"
                    placeholder: "Write a comment..."

                SPAN
                    key: "add"
                    className: "material-icons-outlined md-dark"
                    cursor: "pointer"
                    onClick: () =>
                        box = @refs.comment?.getDOMNode()
                        if box.value
                            uid = Math.random().toString(36).substr(2)
                            # Check for collision.?
                            body = box.value.toString()
                            box.value = ""
                            save
                                key: "#{post}/comment/#{uid}"
                                body: body
                                post_key: post
                                user_key: c.user.key
                                #parent_key: null
                                # Store post time in seconds, not ms
                                time: Math.floor (Date.now() / 1000)

                    "add_comment"

        DIV
            key: "comments-iter"
            display: "contents"

            flattened.map ({key, depth, etc}, i) ->
                if etc
                    DIV
                        key: key
                        marginLeft: 24 * depth + 8
                        marginBottom: 5
                        color: "#999"
                        fontSize: 14
                        "This thread continues."
                else
                    COMMENT
                        key: key
                        comment: key
                        style:
                            # Since tooltips go below user icons, each comment needs to have a higher z-index than the one underneath it.
                            position: "relative"
                            zIndex: flattened.length - i
                            marginLeft: 24 * depth
            DIV
                key: "too-many-comments"
                display: unless too_many_comments then "none"
                color: "#999"
                fontSize: 14
                "Further comments were truncated."
                

# A single comment in a thread.
dom.COMMENT = ->
    c = fetch "/current_user"
    com = fetch @props.comment
    unless com.user_key?
        # The comment has actually just been deleted.
        return

    time_string = prettyDate(com.time * 1000)
    edit_time_string = if com.edit_time then prettyDate(com.edit_time * 1000)
    DIV
        display: "flex"
        flexDirection: "row"
        alignContent: "stretch"

        padding: "5px 0"
        style: @props.style

        AVATAR
            key: "author"
            user: com.user_key
            style:
                borderRadius: "50%"
                width: 24
                height: 24
                marginRight: "8px"
                # Since we set flexGrow on the right part, this needs to not shrink
                flexShrink: 0
                # Anchors tooltip position
                position: "relative"


        DIV
            key: "right-side"
            flexGrow: 1
            display: "flex"
            flexDirection: "column"

            unless @local.editing
                # The actual post body, displayed normally
                DIV
                    key: "post-body"
                    display: "grid"
                    grid: "\"body body body\" auto
                           \"time reply modify\" 16px
                            / auto auto 1fr "
                    gridColumnGap: "8px"
                    DIV
                        key: "body"
                        gridArea: "body"
                        fontSize: 14
                        whiteSpace: "pre-line"
                        com.body

                    SPAN
                        key: "time"
                        gridArea: "time"
                        fontSize: "12px"
                        color: "#999"
                        whiteSpace: "nowrap"
                        overflowX: "hidden"
                        textOverflow: "ellipsis"
                        if edit_time_string then "#{time_string} (edited #{edit_time_string})" else time_string

                    SPAN
                        key: "reply"
                        gridArea: "reply"
                        fontSize: "12px"
                        color: "#999"
                        cursor: "pointer"
                        onClick: () =>
                            @local.replying = true
                            @local.editing = false
                            save @local
                        "reply"
                    
                    if c.user?.key == com.user_key
                        SPAN
                            key: "modify"
                            gridArea: "modify"
                            fontSize: "12px"
                            color: "#999"

                            SPAN
                                key: "edit"
                                cursor: "pointer"
                                marginRight: "8px"
                                onClick: () => 
                                    @local.editing = true
                                    @local.replying = false
                                    # Is it necessary to load the comment body into local for editing?
                                    save @local
                                "edit"
                            ###
                            SPAN
                                key: "delete"
                                cursor: "pointer"
                                onClick: () -> del com.key
                                "delete"
                            ###
            else
                # A textbox with the text of the post body
                DIV
                    key: "post-body"
                    display: "grid"
                    grid: "\"textbox cancel\" auto
                           \"textbox save\" auto
                           \"textbox .\" 1fr
                            / 1fr auto"
                    gridGap: "5px"

                    TEXTAREA
                        key: "editbox"
                        ref: "editbox"
                        gridArea: "textbox"
                        rows: 3
                        resize: "none"
                        placeholder: "Edit your comment..."
                        value: com.body

                    SPAN
                        key: "cancel"
                        gridArea: "cancel"
                        className: "material-icons-outlined md-dark"
                        cursor: "pointer"
                        onClick: () =>
                            @local.editing = false
                            save @local
                        "close"

                    SPAN
                        key: "save"
                        gridArea: "save"
                        className: "material-icons-outlined md-dark"
                        cursor: "pointer"
                        onClick: () =>
                            save {
                                com...
                                body: @refs.editbox.getDOMNode().value.toString()
                                edit_time: Math.floor (Date.now() / 1000)
                            }

                            @local.editing = false
                            save @local
                        "done"

            if @local.replying
                # A textarea for the new comment
                DIV
                    key: "post-reply"
                    display: "grid"
                    grid: "\"avatar textbox cancel\" auto
                           \"avatar textbox save\" auto
                           \". textbox .\" 1fr
                            / auto 1fr auto"
                    gridGap: "3px"
                    marginTop: "5px"

                    AVATAR
                        key: "my-avatar"
                        gridArea: "avatar"
                        user: c.user.key
                        hide_tooltip: yes
                        marginRight: "3px"
                        style:
                            borderRadius: "50%"
                            width: 24
                            height: 24

                    TEXTAREA
                        key: "comment"
                        ref: "comment"
                        gridArea: "textbox"
                        rows: 3
                        resize: "none"
                        placeholder: "Write a reply..."

                    SPAN
                        key: "cancel"
                        gridArea: "cancel"
                        className: "material-icons-outlined md-dark"
                        cursor: "pointer"
                        onClick: () =>
                            @local.replying = false
                            save @local
                        "close"

                    SPAN
                        key: "save"
                        gridArea: "save"
                        className: "material-icons-outlined md-dark"
                        cursor: "pointer"
                        onClick: () =>
                            box = @refs.comment?.getDOMNode()
                            if box.value
                                uid = Math.random().toString(36).substr(2)
                                # Check for collision.?
                                body = box.value.toString()
                                box.value = ""
                                save
                                    key: "#{com.post_key}/comment/#{uid}"
                                    body: body
                                    post_key: com.post_key
                                    user_key: c.user.key
                                    parent_key: com.key
                                    # Store post time in seconds, not ms
                                    time: Math.floor (Date.now() / 1000)

                            @local.replying = false
                            save @local
                        "add_comment"



### === HEADER AND POPUPS === ###
# The BEEG header
dom.HEADER = ->
    c = fetch "/current_user"
   
    DIV
        ref: "headercontainer"
        position: "relative"
        zIndex: 10
        width: outer_width
        DIV
            key: "actual-header"
            ref: "header"
            display: "flex"
            flexDirection: "row"
            alignItems: "center"
            background: "#def"
            padding: "10px #{(outer_width - inner_width)/2}px"
            color: "#444"
            zIndex: 5

            X_OF_Y
                key: "title-dropdown"
                flexGrow: 1

            SPAN
                key: "home"
                margin: 10
                cursor: "pointer"
                onClick: () -> load_path "/"
                "Home"

            A
                key: "about"
                margin: 10
                href: "/about"
                color: "inherit"
                textDecoration: "none"
                "About"

            SPAN
                key: "users"
                margin: 10
                cursor: "pointer"
                onClick: () -> load_path "/users"
                "Users"

            SPAN
                key: "post"
                margin: 10
                cursor: "pointer"
                display: unless c.logged_in then "none"
                onClick: () => 
                    @local.modal = if @local.modal == "post" then false else "post"
                    save @local
                "Post"

            if c.logged_in
                SPAN
                    key: "user"
                    cursor: "pointer"
                    display: "contents"
                    onClick: () => 
                        @local.modal = if @local.modal == "settings" then false else "settings"
                        save @local

                    SPAN
                        key: "name"
                        marginLeft: 14
                        marginRight: 4
                        c.user.name
                    AVATAR
                        key: "avatar"
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
                        save @local
                    "Login"



        DIV
            key: "dropdown"
            display: "none" unless @local.modal 
            position: "absolute"
            right: 0
            zIndex: 6
            marginTop: 10
            padding: 10
            background: "white"
            boxShadow: "rgba(0, 0, 0, 0.15) 0px 1px 5px 1px"

            close = () =>
                @local.modal = false
                save @local

            # register_window_event prevents a new handler from being added when the element is re-rendered
            register_window_event "header-modal", "mousedown", (e) =>
                # should we preventdefault?
                unless @refs.headercontainer.getDOMNode().contains e.target
                    close()
           
            # Display one of various popups
            switch @local.modal
                when "post" then SUBMIT_POST
                    close: close
                    key: "submit-modal"
                when "settings" then SETTINGS
                    close: close
                    key: "settings-modal"
                when "login" then LOGIN
                    close: close
                    key: "login-modal"

# The view text, with rolodex view selectors
dom.X_OF_Y = ->

    v = fetch "view"
    c = fetch "/current_user"
    DIV {
            display: "flex"
            flexDirection: "row"
            justifyContent: "left"
            alignItems: "flex-start"
            height: "1.3em"
            lineHeight: 1.2
            fontSize: 20
            @props...
        },

        if @local.pers
            viewing_user = c?.user?.key ? "/user/default"
            weights = fetch "weights/#{unslash viewing_user}"

            users = (fetch("/users").all ? [])
                .filter (u) -> u.key != viewing_user
                .sort (a, b) -> (weights[b.key] ? 0) - (weights[a.key] ? 0)
            users.unshift fetch viewing_user

            selected_user = if v.user_key then users.findIndex (u) -> u.key == v.user_key else 0
            ROLODEX
                key: "pers-rolo"
                # The array of data to be rendered
                arr: users
                # The index of the initially chosen element
                selected: selected_user
                # Callback for when an entry has been chosen
                close: (chosen) =>
                    if @local.pers
                        load_path if chosen then (users[chosen]?.key ? "/") else "/"
                    @local.pers = false
                    save @local
                # Function to render each element
                render: (user, selected, el_props) ->
                    DIV {
                            key: unslash user.key
                            display: "flex"
                            flexDirection: "row"
                            justifyContent: "left"
                            cursor: "pointer"
                            el_props...
                        },

                        AVATAR
                            key: "avatar"
                            user: user
                            width: 20
                            height: 20
                            marginRight: 8
                            clickable: false
                            hide_tooltip: true
                            style:
                                alignSelf: "center"
                                borderRadius: "50%"
                            
                        SPAN
                            key: "name"
                            color: if selected then "#681"
                            textOverflow: "ellipsis"
                            overflow: "hidden"
                            maxWidth: "12ch"
                            whiteSpace: "nowrap"
                            # Put "You" instead of your own username
                            switch user.key
                                when c?.user?.key then "You"
                                else user.name ? user.key[6..]

        else
            SPAN
                key: "pers-text"
                color: "#681"
                cursor: "pointer"
                onClick: () =>
                    @local.pers = true
                    save @local
                if v.user_key?
                    "#{fetch(v.user_key)?.name ? 'User'}'s"
                else
                    "Your"

        SPAN
            key: "of-spacer"
            whiteSpace: "pre"
            "  view of  "

        if @local.cont
            tags = ["Everything", (fetch("/tags").arr ? [])...]
            selected_tag = if v.tag then tags.indexOf v.tag else 0
            ROLODEX
                key: "cont-rolo"
                arr: tags
                selected: selected_tag
                close: (chosen) =>
                    if @local.cont
                        load_path if chosen then (tags[chosen] ? "/") else "/"
                    @local.cont = false
                    save @local
                # Function to render each element
                render: (tag, selected, el_props) ->
                    DIV {
                            key: tag
                            cursor: "pointer"
                            el_props...
                        },

                        SPAN
                            key: "the_tag"
                            color: if selected then "#c5b"
                            textOverflow: "ellipsis"
                            overflow: "hidden"
                            maxWidth: "12ch"
                            whiteSpace: "nowrap"
                            textTransform: "capitalize"
                            tag

        else
            SPAN
                key: "cont-text"
                color: "#c5b"
                cursor: "pointer"
                textTransform: "capitalize"
                onClick: () =>
                    @local.cont = true
                    save @local
                v.tag ? "everything"


dom.ROLODEX = ->
    n = 0
    scrollOffset = (props) -> SPAN {
            key: "dummy-scroll-offset-#{n++}"
            whiteSpace: "pre"
            pointerEvents: "none"
            props...
        }, " "

    close = () =>
        @props.close?(@local.scroll_index ? 0)

        @local.has_jumped_to_initial = false
        save @local

    # register_window_event prevents a new handler from being added when the element is re-rendered
    register_window_event "#{@props.key}-dropdown", "mousedown", (e) =>
        # should we preventdefault?
        unless @refs?.dropdown?.getDOMNode?()?.contains e.target
            close()
    DIV
        ref: "dropdown"
        className: "hide-scroll"
        display: "flex"
        flexDirection: "column"
        height: "6.65em"
        transform: "translateY(-2.4em)"
        lineHeight: 1.2
        overflowY: "auto"
        scrollBehavior: "smooth"
        style: scrollSnapType: "y mandatory"
        onScroll: () =>
            @local.scroll_index = Math.round @refs.dropdown?.getDOMNode?()?.scrollTop / (20 * 1.2)
            @local.scroll_index -= 3
            save @local
            # TODO: Prefetch some relevant state (particularly the weights) for the selected user...
      
        scrollOffset lineHeight: 3.6
        scrollOffset style: scrollSnapAlign: "start"
        scrollOffset style: scrollSnapAlign: "start"

        n_users = @props.arr.length
        @props.arr.map (data, i) =>
            selected = (@local.scroll_index ? 0) == i
            @props.render data, selected,
                onClick: () =>
                    if selected
                        close()
                    else
                        # 20px fontsize * 1.2 lineheight * (i + 3) elements
                        scrolltop = (i + 3) * 20 * 1.2
                        @refs.dropdown?.getDOMNode?()?.scrollTo top: scrolltop
                style: if i < n_users - 2 then scrollSnapAlign: "start"
                height: 24


        scrollOffset lineHeight: 5

# We use refresh to set the dropdown's scroll position the first time it renders
dom.ROLODEX.refresh = ->
    el = @refs.dropdown?.getDOMNode?()
    # Hmmm, now this can cause weird snapping if you scroll too far up with a trackpad. 
    # Add some local state to keep track of if the element was just rendered?
    if el? and !@local.has_jumped_to_initial and @props.selected != -1
        top = 20 * 1.2 * (3 + @props.selected)
        el.scrollTo top: top, behavior: "instant"
        el.scrollTop = top
        @local.has_jumped_to_initial = true
        save @local


# The submit-post modal
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
                / #{slider_height}px #{inner_width - slider_width}px 1fr "
        alignItems: "center"

        AVATAR
            key: "avatar"
            user: c.user
            hide_tooltip: true
            gridArea: "icon"
            style:
                width: slider_height - 10
                height: slider_height - 10
                borderRadius: "50%"
                alignSelf: "center"
                justifySelf: "center"
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
            height: slider_height
            textAlign: "center"
            alignSelf: "center"
            className: "material-icons-outlined md-dark"
            fontSize: "24px"
            onClick: form_submit
            cursor: "pointer"
            "post_add"



# The login/register modal
dom.LOGIN = ->
    c = fetch "/current_user"
    # We use this check to keep the modal open if login failed
    # More precisely, only close it if login succeeded.
    if c.logged_in and @local.login_attempted
        @local.login_attempted = false
        save @local
        @props.close?()
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
               "register login" 24px
                / auto auto'
        gap: "6px"
        DIV
            key: "error"
            gridArea: "error"
            display: "none" unless c.error
            fontSize: "12px"
            color: "red"
            c.error
        INPUT
            key: "login-name"
            id: "login-name"
            ref: "login-name"
            placeholder: "Username"
            gridArea: "name"
        INPUT
            key: "login-pw"
            id: "login-pw"
            ref: "login-pw"
            placeholder: "Password"
            gridArea: "pw"
            type: "password"

        BUTTON {
            key: "register"
            gridArea: "register"
            button_style...

            onClick: (e) =>
                name = @refs["login-name"].getDOMNode().value
                pw = @refs["login-pw"].getDOMNode().value
                c.create_account =
                    name: name
                    pass: pw
                save c
                delete c.create_account
                c.login_as =
                    name: name
                    pass: pw
                @local.login_attempted = true
                save c
                save @local
            },
            "Register"

        BUTTON {
            key: "login"
            gridArea: "login"
            button_style...
            onClick: (e) =>
                name = @refs["login-name"].getDOMNode().value
                pw = @refs["login-pw"].getDOMNode().value
                c.login_as =
                    name: name
                    pass: pw
                @local.login_attempted = true
                save c
                save @local

            },
            "Login"

# The modal for the logged-in user's settings
dom.SETTINGS = ->
    c = fetch "/current_user"
    unless c.logged_in
        return
    DIV
        width: "300"
        display: "grid"
        # Maybe use flex instead here?
        alignContent: "center"
        grid: '"nametag namefield namefield" 32px
               "emailtag emailfield emailfield" 32px
               "pictag picfield picfield" 32px
               "filtertag filterfield filterfield" 32px
               "logout cancel save" 24px
                / auto auto auto'
        gridGap: "5px"
        
        DIV
            key: "name"
            gridArea: "nametag"
            color: "#333"
            fontSize: "12px"
            "Name"
        INPUT
            key: "name-change"
            gridArea: "namefield"
            ref: "name"
            value: c.user.name
            id: "name-change"

        DIV
            key: "email"
            gridArea: "emailtag"
            color: "#333"
            fontSize: "12px"
            "Email"
        INPUT
            key: "email-change"
            gridArea: "emailfield"
            ref: "email"
            value: c.user.email
            id: "email-change"
            type: "email"

        DIV
            key: "pic"
            gridArea: "pictag"
            color: "#333"
            fontSize: "12px"
            "Avatar URL"
        INPUT
            key: "pic-change"
            gridArea: "picfield"
            ref: "pic"
            value: c.user.pic
            placeholder: "http://..."
            id: "pic-change"
        DIV
            key: "filter"
            gridArea: "filtertag"
            color: "#333"
            fontSize: "12px"
            "Min post score"
        INPUT
            key: "filter-change"
            gridArea: "filterfield"
            ref: "filter"
            value: c.user.filter
            placeholder: -0.2
            id: "filter-change"
            type: "number"
            step: 0.1


        BUTTON
            key: "cancel"
            gridArea: "cancel"
            onClick: () => @props.close?()
            "Cancel"

        BUTTON
            key: "logout"
            gridArea: "logout"
            onClick: () =>
                @props.close?()
                c.logout = true
                save c
            "Logout"

        BUTTON
            key: "save"
            gridArea: "save"
            onClick: () =>
                
                name = @refs.name.getDOMNode().value
                email = @refs.email.getDOMNode().value
                pic = @refs.pic.getDOMNode().value ? ""
                filter = @refs.filter.getDOMNode().value
                filter = Number.parseFloat filter
                if isNaN filter
                    filter = -0.2

                c.user.name = name
                c.user.email = email
                c.user.pic = pic
                c.user.filter = filter

                save c.user
                
                # Close the settings box
                @props.close?()
            "Save"




### === ALL USER DISPLAY === ###
# The list of all users
dom.USERS = ->
    c = fetch "/current_user"
    # TODO: allow viewing users with tags?

    # Default to New sorting
    @local.sort ?= "top"
    save @local

    if @local.sort == "top"
        user = c?.user?.key ? "/user/default"
        weights = fetch "weights/#{unslash user}"

    sort_func = switch @local.sort
        when "new" then (a, b) -> (b.joined ? 0) - (a.joined ? 0)
        when "old" then (a, b) -> (a.joined ? 0) - (b.joined ? 0)
        when "top" then (a, b) -> (weights[b.key] ? 0) - (weights[a.key] ? 0)
        else (a, b) -> 0

    users = ((fetch "/users").all ? [])
        .filter (u) -> u.key != c?.user?.key
        .sort sort_func
    DIV
        key: "users"
        DIV
            key: "sort-select"
            display: "flex"
            flexDirection: "row"
            justifyContent: "space-evenly"

            ["top", "new", "old"].map (s) =>
                SPAN
                    key: s
                    textTransform: "capitalize"
                    fontSize: 20
                    color: if @local.sort == s then "black" else "#999"
                    cursor: "pointer" unless @local.sort == s
                    onClick: () =>
                        @local.sort = s
                        save @local
                    s

        DIV
            key: "user-list"
            users.map (user) =>
                USER
                    user: user.key
                    key: unslash user.key

# The layout for a user in a user feed
dom.USER = ->
    user = @props.user
    # Subscribe to the user
    if user?.key or typeof user == "string" then user = fetch user
    c = fetch "/current_user"

    joined_string = prettyDate(user.joined ? 0)

    DIV
        margin: "5px 0"
        padding: "5px 10px"
        #boxShadow: if @local.expanded then "rgba(0, 0, 0, 0.15) 0px 1px 5px 1px"
        DIV
            key: "user-main"
            display: "grid"
            width: outer_width
            grid: "\"icon name slider more\" auto
                   \"icon joined slider more\" 16px
                    / 1fr #{inner_width - slider_width}px #{slider_width}px 1fr"
            alignItems: "center"

            AVATAR
                key: "avatar"
                user: user
                width: slider_height - 10
                height: slider_height - 10
                style:
                    gridArea: "icon"
                    alignSelf: "center"
                    borderRadius: "50%"

            SPAN
                key: "name"
                gridArea: "name"
                fontSize: "18px"
                paddingRight: "10px"
                justifySelf: "stretch"
                user.name ? user.key[6..]

            SPAN
                key: "joined"
                gridArea: "joined"
                fontSize: "12px"
                color: "#999"
                whiteSpace: "nowrap"
                overflowX: "hidden"
                "Joined #{joined_string}"
           
            DIV
                key: "user-votes-slider"
                gridArea: "slider"
                alignSelf: "start"
                height: slider_height + 5
                # TODO: Create a UI for viewing users wrt a tag
                SLIDERGRAM
                    key: "slidergram"
                    sldr: "/votes/#{unslash user.key}(untagged)"
                    width: slider_width
                    height: slider_height
                    max_avatar_radius: slider_height / 2
                    read_only: !c.logged_in
                    vote_key: "user_key"
                    onsave: (vote) =>
                        vote.key = "#{c.user.key}/vote/#{unslash user.key}"
                        vote.target_key = user.key
                        save vote

            SPAN
                key: "more"
                gridArea: "more"
                color: "#999"
                className: "material-icons-outlined md-dark"
                fontSize: "24px"
                cursor: "pointer"
                textAlign: "center"
                onClick: () => 
                    @local.expanded = !@local.expanded
                    save @local
                if @local.expanded then "expand_less" else "expand_more"

        if @local.expanded
            POST_DETAILS
                key: "details-dropdown"
                post: user
