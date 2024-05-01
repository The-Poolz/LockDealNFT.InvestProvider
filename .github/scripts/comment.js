module.exports = async ({ github, context, header, body }) => {
    const comment = [header, body].join("\n")

    const { data: comments } = await github.rest.issues.listComments({
        owner: context.repo.owner,
        repo: context.repo.repo,
        issue_number: context.payload.number,
    })

    // Find the existing bot comment, if it exists
    const botComment = comments.find((c) => c.user.id === 41898282 && c.body.startsWith(header))

    // If there's an existing bot comment, delete it
    if (botComment) {
        await github.rest.issues.deleteComment({
            owner: context.repo.owner,
            repo: context.repo.repo,
            comment_id: botComment.id,
        })
    }

    // Create a new comment
    await github.rest.issues.createComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        issue_number: context.payload.number,
        body: comment,
    })
}
