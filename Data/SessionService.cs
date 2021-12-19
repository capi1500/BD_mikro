using System.Data;
using Dapper;

namespace Conference.Data;

public sealed class SessionService
{
    private readonly IDbConnection _dbConnection;

    public SessionService(IDbConnection dbConnection) =>
        _dbConnection = dbConnection;

    public IReadOnlyList<Session> GetSessions()
    {
        var sessions = _dbConnection.Query<Session, Author, Session>(
            @"
                SELECT 
                    s.id AS sessionId,
                    s.when,
                    a.id AS authorId,
                    a.name,
                    a.surname
                FROM
                    session s JOIN author a ON s.chair_id = a.id
                    ",
            (s, a) =>
            {
                s.Chair = a;
                return s;
            },
            splitOn: "authorId"
        ).ToList();

        var lectures = _dbConnection.Query<Lecture, Author, Paper, Session, Lecture>(
            @"
                SELECT
                    l.id AS lectureId,
                    a.id AS authorId,
                    a.name,
                    a.surname,
                    p.id AS paperId,
                    p.name,
                    p.classification AS classification,
                    s.id AS sessionId,
                    s.when
                FROM
                    lecture l 
                        JOIN paper p ON l.paper_id = p.id
                        JOIN session s ON l.session_id = s.id
                        JOIN author a ON a.id = l.speaker_id
                ",
            (l,a, p, s) =>
            {
                l.Session = s;
                l.Paper = p;
                l.Speaker = a;
                l.When = s.When;
                return l;
            },
            splitOn: "authorId,paperId,sessionId"
        ).ToList();

        
        PaperService paperService = new PaperService(_dbConnection);
        var papers = paperService.GetPapers();

        foreach (var p in papers)
        {
            var lst = lectures.FindAll(l => l.Paper.Id == p.Id);
            foreach (var l in lst)
                l.Paper = p;
        }
        
        foreach (var l in lectures)
        {
            var s = sessions.Find(s => s.Id == l.Session.Id);
            if (s != null)
            {
                s.Lectures.Add(l);
                Console.Out.WriteLine(l.Id);
                foreach (var a in l.Paper.Authors)
                    Console.Out.WriteLine(a);
            }
        }

        return sessions;
    }

    public void CreateSession(CreateSession model)
    {
        if (model.ChairId is null)
        {
            throw new ArgumentNullException();
        }

        _dbConnection.Execute(
            $"INSERT INTO session (\"when\", chair_id) VALUES (@When, @ChairId);",
            new { model.When, model.ChairId });
    }
}