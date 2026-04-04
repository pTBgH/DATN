<table class="dataframe">
    <thead>
        <tr>
            <th>Title</th>
            <th>Company</th>
            <th>City</th>
            <th>District</th>
            <th>Job Type</th>
            <th>Experience (Years)</th>
            <th>Minimum Salary</th>
            <th>Deadline</th>
            <th>Days Since Open</th>
            <th>Score</th>
        </tr>
    </thead>
    <tbody>
        @forelse ($jobs as $job)
            <tr>
                <td>{{ $job['title'] }}</td>
                <td>{{ $job['company_name'] }}</td>
                <td>{{ $job['city_name'] }}</td>
                <td>{{ $job['district_name'] }}</td>
                <td>{{ $job['job_type'] }}</td>
                <td>{{ $job['experience_years'] }}</td>
                <td>{{ $job['salary_min'] }}</td>
                <td>{{ $job['deadline'] }}</td>
                <td>{{ $job['days_since_open'] }}</td>
                <td>{{ $job['score'] }}</td>
            </tr>
        @empty
            <tr>
                <td colspan="10" style="text-align: center;">No jobs found.</td>
            </tr>
        @endforelse
    </tbody>
</table>
