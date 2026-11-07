document.getElementById('student-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;

  const payload = {
    student_name: document.getElementById('student_name').value.trim(),
    student_email: document.getElementById('student_email').value.trim().toLowerCase(),
    school: document.getElementById('school').value.trim(),
    grade: document.getElementById('grade').value.trim(),
    notes: document.getElementById('notes').value.trim()
  };

  if (!payload.student_name || !payload.student_email) {
    setStatus('Name and email are required.', true);
    return;
  }

  setStatus('Adding student…');

  const { data: sessionData, error: sessionError } = await client.auth.getSession();
  if (sessionError || !sessionData?.session) {
    setStatus('Your session expired. Please sign in again.', true);
    return;
  }

  const { data, error } = await client
    .from('education_students')
    .insert([
      {
        user_id: sessionData.session.user.id,
        student_name: payload.student_name,
        student_email: payload.student_email,
        school: payload.school || null,
        grade: payload.grade || null,
        notes: payload.notes || null
      }
    ])
    .select();

  if (error) {
    setStatus(error.message || 'Could not create student.', true);
    return;
  }

  setStatus('Student added successfully. Share the student sign-in page and have them register using this email address.');
  form.reset();
  await loadStudents();
.eq('user_id', sessionData.session.user.id)
});
