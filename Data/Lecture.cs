namespace Conference.Data;

public class Lecture 
{
    public int Id { get; init; }

    public DateTime? When { get; set; }

    public Author? Speaker { get; set; }
    
    public Paper? Paper { get; set; }
    
    public Session? Session { get; set; }
    
    public Lecture(int lectureId) => 
        (Id) = (lectureId);
}